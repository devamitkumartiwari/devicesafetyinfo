import UIKit

/// Refusing third-party keyboard extensions (they could log what's typed).
///
/// Flutter doesn't forward `application(_:shouldAllowExtensionPointIdentifier:)` to plugins, so
/// the app's `AppDelegate` asks this type:
///
/// ```swift
/// import device_safety_info
///
/// override func application(
///   _ application: UIApplication,
///   shouldAllowExtensionPointIdentifier id: UIApplication.ExtensionPointIdentifier
/// ) -> Bool {
///   DeviceSafetyInfoPlugin.shouldAllowExtension(id)
/// }
/// ```
///
/// The setting (`DeviceSafety.keyboard.blockCustomKeyboards(true)` in Dart) is stored, because
/// iOS may ask before Dart has run.
enum KeyboardPolicy {
    private static let key = "dsi.blockCustomKeyboards"

    static var blockCustomKeyboards: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    static func shouldAllow(_ id: UIApplication.ExtensionPointIdentifier) -> Bool {
        !(id == .keyboard && blockCustomKeyboards)
    }
}

extension DeviceSafetyInfoPlugin {
    /// Call from `AppDelegate.application(_:shouldAllowExtensionPointIdentifier:)`. Returns
    /// `false` for third-party keyboards once `DeviceSafety.keyboard.blockCustomKeyboards(true)`
    /// was called; `true` otherwise.
    public static func shouldAllowExtension(
        _ id: UIApplication.ExtensionPointIdentifier
    ) -> Bool {
        KeyboardPolicy.shouldAllow(id)
    }
}
