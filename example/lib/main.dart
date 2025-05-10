import 'dart:io';
import 'package:device_safety_info/device_safety_info.dart';
import 'package:device_safety_info/new_version_check.dart';
import 'package:device_safety_info/vpn_check.dart';
import 'package:device_safety_info/vpn_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isRootedDevice = false;
  bool isScreenLock = false;
  bool isRealDevice = true;
  bool isExternalStorage = false;
  bool isDeveloperMode = false;
  bool isVPN = false;
  bool isInstalledFromStore = false;

  final vpnCheck = VPNCheck();

  @override
  void initState() {
    super.initState();
    _initializeDeviceInfo();
    _vpnStatus();
  }

  // Initialize device safety information
  Future<void> _initializeDeviceInfo() async {
    if (!mounted) return;
    try {
      // Create the list of device info based on platform
      final deviceInfo = await Future.wait([
        DeviceSafetyInfo.isRootedDevice,
        DeviceSafetyInfo.isScreenLock,
        DeviceSafetyInfo.isRealDevice,
        if (Platform.isAndroid) ...[
          DeviceSafetyInfo.isExternalStorage,
          DeviceSafetyInfo.isDeveloperMode,
        ],
        DeviceSafetyInfo.isInstalledFromStore,
      ]);

      setState(() {
        isRootedDevice = deviceInfo[0];
        isScreenLock = deviceInfo[1];
        isRealDevice = deviceInfo[2];
        isExternalStorage = Platform.isAndroid && deviceInfo.length > 3
            ? deviceInfo[3]
            : false; // Only access for Android
        isDeveloperMode = Platform.isAndroid && deviceInfo.length > 4
            ? deviceInfo[4]
            : false; // Only access for Android
        isInstalledFromStore =
            deviceInfo.last; // Use last element for isInstalledFromStore
      });
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching device info: $e");
      }
    }
  }

  // Check VPN status
  void _vpnStatus() {
    vpnCheck.vpnState.listen((state) {
      final vpnConnected = state == VPNState.connectedState;
      if (kDebugMode) {
        print(vpnConnected ? "VPN connected." : "VPN disconnected.");
      }
      setState(() {
        isVPN = vpnConnected;
      });
    });
  }

  // App version status check
  Future<void> _appVersionStatus() async {
    final newVersion = NewVersionChecker(iOSId: '', androidId: '');
    try {
      final status = await newVersion.getVersionStatus();
      if (status != null && status.canUpdate) {
        if (kDebugMode) {
          print("New version available: ${status.storeVersion}");
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error checking app version: $e");
      }
    }
  }

  // Build the UI layout
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Device Safety Info')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListView(
              children: [
                _infoTile(
                  methodRequest: 'isRootedDevice',
                  methodResponse: isRootedDevice,
                ),
                _infoTile(
                  methodRequest: 'isScreenLock',
                  methodResponse: isScreenLock,
                ),
                _infoTile(
                  methodRequest: 'isRealDevice',
                  methodResponse: isRealDevice,
                ),
                if (Platform.isAndroid) ...[
                  _infoTile(
                    methodRequest: 'isExternalStorage',
                    methodResponse: isExternalStorage,
                  ),
                  _infoTile(
                    methodRequest: 'isDeveloperMode',
                    methodResponse: isDeveloperMode,
                  ),
                ],
                _infoTile(
                  methodRequest: 'isVPN',
                  methodResponse: isVPN,
                ),
                _infoTile(
                  methodRequest: 'isInstalledFromStore',
                  methodResponse: isInstalledFromStore,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Reusable infoTile widget
  Widget _infoTile(
      {required String methodRequest, required bool methodResponse}) {
    return Container(
      height: 60,
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(methodRequest)),
          Text(
            methodResponse ? "Yes" : "No",
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
