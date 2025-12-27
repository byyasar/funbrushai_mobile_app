import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let themeChannel = FlutterMethodChannel(name: "com.funbrushai.app/theme",
                                          binaryMessenger: controller.binaryMessenger)
    themeChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "setTheme" {
        if let args = call.arguments as? [String: Any],
           let modeStr = args["mode"] as? String {
             // Ensure UI updates happen on main thread
             DispatchQueue.main.async {
               if modeStr == "ThemeMode.dark" {
                   self.window?.overrideUserInterfaceStyle = .dark
               } else if modeStr == "ThemeMode.light" {
                   self.window?.overrideUserInterfaceStyle = .light
               } else {
                   self.window?.overrideUserInterfaceStyle = .unspecified
               }
             }
        }
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    })

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
