import Foundation

/// Overlay (tapjacking) attacks don't exist on iOS: app sandboxing prevents one app from
/// drawing over another. The action reports unsupported; the stream simply never fires.
final class OverlayAttackHostApiImpl: OverlayAttackHostApi {
    func blockTouchesWhenObscured(block: Bool) throws {
        throw PluginSupport.unsupported("blockTouchesWhenObscured")
    }
}

final class OverlayAttackMonitor: OverlayAttackStreamHandler {}
