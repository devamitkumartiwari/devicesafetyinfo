import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_safety_info/vpn_state.dart';
import 'package:flutter/services.dart';

class VPNCheck {
  static const MethodChannel _channel = MethodChannel('device_safety_info');

  // Singleton Part
  // Creates or retrieves an instance of the VPNDetector.
  factory VPNCheck() {
    _instance ??= VPNCheck._private();
    return _instance!;
  }

  VPNCheck._private() {
    _streamSubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) async {
      await _checkVPNStatus();
    });
  }

  final StreamController<VPNState> _streamController = StreamController.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _streamSubscription;

  //check weather VPN connection
  static Future<bool> isVPNActive() async {
    return isVPNCheck;
  }

  static Future<bool> get isVPNCheck async {
    final bool isVPNCheck = await _channel.invokeMethod('isVPNCheck');
    return isVPNCheck;
  }

  // singleton instance
  static VPNCheck? _instance;

  // get VPN state
  Stream<VPNState> get vpnState => _streamController.stream.asBroadcastStream();

  Future<void> _checkVPNStatus() async {
    final currentVpnStatus = await isVPNActive();
    if (currentVpnStatus) {
      _streamController.add(VPNState.connectedState);
    } else {
      _streamController.add(VPNState.disconnectedState);
    }
  }

  // dispose all streams
  void dispose() {
    _streamController.close();
    _streamSubscription?.cancel();
  }
}
