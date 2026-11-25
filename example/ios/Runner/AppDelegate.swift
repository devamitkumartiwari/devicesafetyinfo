import Flutter
import UIKit
import device_safety_info

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Lets DeviceSafety.keyboard.blockCustomKeyboards(true) refuse third-party keyboards.
  override func application(
    _ application: UIApplication,
    shouldAllowExtensionPointIdentifier id: UIApplication.ExtensionPointIdentifier
  ) -> Bool {
    DeviceSafetyInfoPlugin.shouldAllowExtension(id)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
