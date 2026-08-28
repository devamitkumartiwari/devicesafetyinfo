import 'dart:async';

import 'package:flutter/services.dart';

import '../core/device_safety_channels.dart';
import 'vpn_state.dart';

/// Singleton VPN monitor. Use the [VPNCheck] factory constructor to get the shared instance, then
/// listen to [vpnState] for live updates or await [isVpnActive] for a one-off check.
class VPNCheck {
  /// Returns the shared [VPNCheck] instance, creating it on first call.
  factory VPNCheck() {
    _instance ??= VPNCheck._private();
    return _instance!;
  }

  VPNCheck._private() {
    _streamSubscription = DeviceSafetyChannels.connectivity
        .receiveBroadcastStream()
        .listen((_) async => _checkVPNStatus());
    // Emit initial state immediately so listeners receive a value
    // without waiting for the next connectivity change event.
    _checkVPNStatus();
  }

  // StreamController.broadcast() already produces a broadcast stream —
  // no second .asBroadcastStream() call needed.
  final StreamController<VPNState> _streamController =
      StreamController.broadcast();
  StreamSubscription<dynamic>? _streamSubscription;

  static VPNCheck? _instance;

  /// Returns true if a VPN connection is currently active.
  static Future<bool> get isVpnActive async {
    try {
      final bool result =
          await DeviceSafetyChannels.method.invokeMethod<bool>('isVPNCheck') ??
          false;
      return result;
    } on PlatformException {
      return false;
    }
  }

  /// Deprecated: use [isVpnActive] instead.
  @Deprecated('Use isVpnActive instead')
  static Future<bool> isVPNActive() => isVpnActive;

  /// Emits [VPNState] whenever the network connectivity changes.
  Stream<VPNState> get vpnState => _streamController.stream;

  Future<void> _checkVPNStatus() async {
    final active = await isVpnActive;
    _streamController.add(
      active ? VPNState.connectedState : VPNState.disconnectedState,
    );
  }

  /// Closes the state stream and cancels the underlying connectivity subscription.
  void dispose() {
    _streamController.close();
    _streamSubscription?.cancel();
  }
}
