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
  }
}
