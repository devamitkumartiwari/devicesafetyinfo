import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_safety_info/vpn_state.dart';
import 'package:flutter/services.dart';

class VPNCheck {
  static const MethodChannel _channel = MethodChannel('device_safety_info');

  factory VPNCheck() {
    _instance ??= VPNCheck._private();
    return _instance!;
  }

  VPNCheck._private() {
    _streamSubscription = Connectivity().onConnectivityChanged.listen(
          (_) async => _checkVPNStatus(),
        );
    // Emit initial state immediately so listeners receive a value
    // without waiting for the next connectivity change event.
    _checkVPNStatus();
  }

  // StreamController.broadcast() already produces a broadcast stream —
  // no second .asBroadcastStream() call needed.
  final StreamController<VPNState> _streamController =
      StreamController.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _streamSubscription;

  static VPNCheck? _instance;

  // Returns true if a VPN connection is currently active.
  static Future<bool> get isVpnActive async {
    try {
      final bool result = await _channel.invokeMethod<bool>('isVPNCheck') ?? false;
      return result;
    } on PlatformException {
      return false;
    }
  }

  @Deprecated('Use isVpnActive instead')
  static Future<bool> isVPNActive() => isVpnActive;

  // Emits VPNState whenever the network connectivity changes.
  Stream<VPNState> get vpnState => _streamController.stream;

  Future<void> _checkVPNStatus() async {
    final active = await isVpnActive;
    _streamController
        .add(active ? VPNState.connectedState : VPNState.disconnectedState);
  }

  void dispose() {
    _streamController.close();
    _streamSubscription?.cancel();
  }
}
