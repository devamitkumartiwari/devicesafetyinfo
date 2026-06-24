import 'dart:ffi';
import 'dart:io';

typedef _Int32NativeFunc = Int32 Function();
typedef _Int32DartFunc = int Function();

/// Low-level FFI bindings for native C security checks.
///
/// These checks run in native C/C++ code, making them significantly
/// harder to intercept with hooking frameworks (Frida, Xposed) than
/// equivalent checks performed at the JVM or Swift runtime level.
class DeviceSafetyFfi {
  static DynamicLibrary? _lib;
  // Tracks whether a load has been attempted so failed loads don't retry
  // on every subsequent call (e.g. in test environments without the .so).
  static bool _loadAttempted = false;

  static DynamicLibrary? _openLib() {
    if (_loadAttempted) return _lib;
    _loadAttempted = true;
    try {
      if (Platform.isAndroid) {
        _lib = DynamicLibrary.open('libdevice_safety_ffi.so');
      } else {
        // On iOS all plugin code is statically linked into the process.
        _lib = DynamicLibrary.process();
      }
    } catch (_) {
      // Library unavailable (e.g. running in a test environment).
    }
    return _lib;
  }

  static _Int32DartFunc? _lookup(String symbol) {
    try {
      return _openLib()
          ?.lookupFunction<_Int32NativeFunc, _Int32DartFunc>(symbol);
    } catch (_) {
      return null;
    }
  }

  /// Scans `/proc/self/maps` for Frida library signatures (Android only).
  /// Always returns `false` on iOS — delegated to IOSSecuritySuite Swift side.
  static bool checkFridaByMaps() {
    try {
      return (_lookup('dsi_check_frida_maps')?.call() ?? 0) != 0;
    } catch (_) {
      return false;
    }
  }

  /// Returns `true` if a debugger is currently attached to the process.
  /// Uses `TracerPid` from `/proc/self/status` on Android and
  /// `sysctl P_TRACED` on iOS.
  static bool isDebuggerAttached() {
    try {
      return (_lookup('dsi_is_debugger_attached')?.call() ?? 0) != 0;
    } catch (_) {
      return false;
    }
  }

  /// Checks common root indicator file paths via native `stat()` (Android only).
  /// Always returns `false` on iOS — handled by IOSSecuritySuite.
  static bool checkRootFilesNative() {
    try {
      return (_lookup('dsi_check_root_files')?.call() ?? 0) != 0;
    } catch (_) {
      return false;
    }
  }
}
