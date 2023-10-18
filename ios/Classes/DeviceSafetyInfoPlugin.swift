import Flutter
import UIKit
import IOSSecuritySuite
import LocalAuthentication

public class DeviceSafetyInfoPlugin: NSObject, FlutterPlugin {

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "device_safety_info", binaryMessenger: registrar.messenger())
    let instance = DeviceSafetyInfoPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
      break
    case "isRootedDevice":
      let check2 = IOSSecuritySuite.amIJailbroken()
      result(check2)
      break
    case "isRealDevice":
        var deviceType = IOSSecuritySuite.amIRunInEmulator()
        var resultData = deviceType == true ? false : true
        result(resultData)
      break
    case "isScreenLock":
        var context = LAContext()
        var isLockScreenEnabled1 = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        if(isLockScreenEnabled1){
            result(isLockScreenEnabled1)
        }else{
            result(isLockScreenEnabled1)
        }

      break
    default:
      result(FlutterMethodNotImplemented)
    }
  }
    
    
}
