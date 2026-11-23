import EventKit
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Register TTS Save Plugin
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "TtsSavePlugin") {
      TtsSavePlugin.register(with: registrar)
    }

    let themeChannel = FlutterMethodChannel(name: "com.funbrushai.app/theme",
                                          binaryMessenger: engineBridge.applicationRegistrar.messenger())
    themeChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "setTheme" {
        if let args = call.arguments as? [String: Any],
           let modeStr = args["mode"] as? String {
             DispatchQueue.main.async {
               let style: UIUserInterfaceStyle
               if modeStr == "ThemeMode.dark" {
                 style = .dark
               } else if modeStr == "ThemeMode.light" {
                 style = .light
               } else {
                 style = .unspecified
               }
               for scene in UIApplication.shared.connectedScenes {
                 if let windowScene = scene as? UIWindowScene {
                   for window in windowScene.windows {
                     window.overrideUserInterfaceStyle = style
                   }
                 }
               }
             }
        }
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    })

    let calendarChannel = FlutterMethodChannel(
      name: "com.funbrushai.app/calendar",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    calendarChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      let eventStore = EKEventStore()

      func requestCalendarAccess(completion: @escaping (Bool, Error?) -> Void) {
        if #available(iOS 17.0, *) {
          eventStore.requestFullAccessToEvents { granted, error in
            completion(granted, error)
          }
        } else {
          eventStore.requestAccess(to: .event) { granted, error in
            completion(granted, error)
          }
        }
      }

      if call.method == "upsertEvent" || call.method == "addEvent" {
        guard let args = call.arguments as? [String: Any],
              let title = args["title"] as? String,
              let startMillis = args["startMillis"] as? NSNumber,
              let endMillis = args["endMillis"] as? NSNumber else {
          result(["success": false, "error": "invalid_arguments"])
          return
        }
        let existingEventId = args["eventId"] as? String
        let notes = args["notes"] as? String ?? ""
        let location = args["location"] as? String ?? ""
        let alarmMinutes = args["alarmMinutes"] as? [Int] ?? []

        requestCalendarAccess { granted, error in
          DispatchQueue.main.async {
            guard granted else {
              result([
                "success": false,
                "error": error?.localizedDescription ?? "permission_denied"
              ])
              return
            }

            var event: EKEvent?
            var wasUpdated = false
            if let eid = existingEventId, !eid.isEmpty,
               let found = eventStore.event(withIdentifier: eid) {
              event = found
              wasUpdated = true
            } else {
              let created = EKEvent(eventStore: eventStore)
              created.calendar = eventStore.defaultCalendarForNewEvents
              event = created
            }

            guard let targetEvent = event else {
              result(["success": false, "error": "event_creation_failed"])
              return
            }

            targetEvent.title = title
            targetEvent.notes = notes
            targetEvent.location = location
            targetEvent.startDate = Date(timeIntervalSince1970: startMillis.doubleValue / 1000.0)
            targetEvent.endDate = Date(timeIntervalSince1970: endMillis.doubleValue / 1000.0)

            // Eski alarmları temizleyip güncel hatırlatıcıları ekle
            if let existingAlarms = targetEvent.alarms {
              for alarm in existingAlarms {
                targetEvent.removeAlarm(alarm)
              }
            }
            for mins in alarmMinutes {
              if mins > 0 {
                targetEvent.addAlarm(EKAlarm(relativeOffset: -Double(mins * 60)))
              }
            }

            do {
              try eventStore.save(targetEvent, span: .thisEvent)
              result([
                "success": true,
                "updated": wasUpdated,
                "eventId": targetEvent.eventIdentifier ?? ""
              ])
            } catch {
              result(["success": false, "error": error.localizedDescription])
            }
          }
        }
      } else if call.method == "deleteEvent" {
        guard let args = call.arguments as? [String: Any],
              let eventId = args["eventId"] as? String,
              !eventId.isEmpty else {
          result(["success": true, "deleted": false])
          return
        }

        requestCalendarAccess { granted, error in
          DispatchQueue.main.async {
            guard granted else {
              result([
                "success": false,
                "error": error?.localizedDescription ?? "permission_denied"
              ])
              return
            }
            if let existing = eventStore.event(withIdentifier: eventId) {
              do {
                try eventStore.remove(existing, span: .thisEvent)
                result(["success": true, "deleted": true])
              } catch {
                result(["success": false, "error": error.localizedDescription])
              }
            } else {
              result(["success": true, "deleted": false])
            }
          }
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
