import Flutter
import UIKit

/// Dispatch protocol each feature handler implements so `DeviceSafetyInfoPlugin.handle` can route
/// by method name via a flat lookup instead of one giant `switch`, mirroring the Android side's
/// `FeatureMethodHandler`.
protocol DSIMethodHandler {
    var methods: Set<String> { get }
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult)
}

/// Small helpers shared by every handler that needs to add a view over the app's window
/// (screenshot overlay modes, the recents overlay) or convert a Flutter-style packed ARGB color.
/// Kept as free functions on an uninstantiable enum rather than duplicated per-handler.
enum PluginHelpers {
    /// Scene-based key-window lookup on iOS 15+, falling back to UIApplication.windows pre-15.
    static var keyWindow: UIWindow? {
        if #available(iOS 15.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.windows.first(where: { $0.isKeyWindow })
        } else {
            return UIApplication.shared.windows.first(where: { $0.isKeyWindow })
        }
    }

    /// Converts a Flutter-style packed ARGB Int into a UIColor.
    static func uiColor(fromARGB value: Int) -> UIColor {
        let a = CGFloat((value >> 24) & 0xFF) / 255.0
        let r = CGFloat((value >> 16) & 0xFF) / 255.0
        let g = CGFloat((value >> 8) & 0xFF) / 255.0
        let b = CGFloat(value & 0xFF) / 255.0
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}
