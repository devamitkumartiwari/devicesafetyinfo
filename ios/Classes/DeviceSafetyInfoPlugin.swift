import Flutter
import UIKit
import IOSSecuritySuite
import LocalAuthentication
// import VpnChecker

public class DeviceSafetyInfoPlugin: NSObject, FlutterPlugin {

private let vpnProtocolsKeysIdentifiers = [
            "tap", "tun", "ppp", "ipsec", "utun"
        ]

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
    case "isVPNCheck":
        let isVPN = isVpnActive()
        result(isVPN)
        break
    default:
      result(FlutterMethodNotImplemented)
    }
  }
    
    func isVpnActive() -> Bool {
               guard let cfDict = CFNetworkCopySystemProxySettings() else { return false }
               let nsDict = cfDict.takeRetainedValue() as NSDictionary
               guard let keys = nsDict["__SCOPED__"] as? NSDictionary,
                   let allKeys = keys.allKeys as? [String] else { return false }

               // Checking for tunneling protocols in the keys
               for key in allKeys {
                   for protocolId in vpnProtocolsKeysIdentifiers
                       where key.starts(with: protocolId) {
                       return true
                   }
               }
               return false
           }

}
