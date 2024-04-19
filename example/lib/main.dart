import 'dart:io';

import 'package:devicesafetyinfo/device_safety_info.dart';
import 'package:devicesafetyinfo/new_version_check.dart';
import 'package:devicesafetyinfo/vpn_check.dart';
import 'package:devicesafetyinfo/vpn_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isRootedDevice = false;
  bool isScreenLock = false;
  bool isRealDevice = true;
  bool isExternalStorage = false;
  bool isDeveloperMode = false;
  final vpnCheck = VPNCheck();
  bool isVPN = false;

  @override
  void initState() {
    super.initState();
    initPlatformState();
    vpnStatus();
  }

  Future<void> initPlatformState() async {
    if (!mounted) return;
    try {
      isRootedDevice = await DeviceSafetyInfo.isRootedDevice;
      isScreenLock = await DeviceSafetyInfo.isScreenLock;
      isRealDevice = await DeviceSafetyInfo.isRealDevice;
      // isVPN = await DeviceSafetyInfo.isVPNCheck;

      if(Platform.isAndroid){
        isExternalStorage = await DeviceSafetyInfo.isExternalStorage;
        isDeveloperMode = await DeviceSafetyInfo.isDeveloperMode;
      }

    } catch (error) {
      print(error);
    }

    setState(() {
      isRootedDevice = isRootedDevice;
      isScreenLock = isScreenLock;
      isRealDevice = isRealDevice;
      isExternalStorage = isExternalStorage;
      isDeveloperMode = isDeveloperMode;
      // isVPN = isVPN;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Device Safety Info'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListView(
              children: [
                infoTile(
                    methodRequest: 'isRootedDevice',
                    methodResponse: isRootedDevice),
                infoTile(
                    methodRequest: 'isScreenLock',
                    methodResponse: isScreenLock),
                infoTile(
                    methodRequest: 'isRealDevice',
                    methodResponse: isRealDevice),

                infoTile(
                    methodRequest: 'isExternalStorage',
                    methodResponse: isExternalStorage),
                infoTile(
                    methodRequest: 'isDeveloperMode',
                    methodResponse: isDeveloperMode),

                infoTile(
                    methodRequest: 'isVPN',
                    methodResponse: isVPN),

              ],
            ),
          ),
        ),
      ),
    );
  }

  infoTile({required String methodRequest, required bool methodResponse}) {
    if (kDebugMode) {
      print(methodResponse);
    }
    return Container(
      height: 60,
      width: MediaQuery.of(context).size.width,
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(methodRequest),
          const SizedBox(
            width: 10,
          ),
          Text(
            methodResponse ? "Yes" : "No",
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  vpnStatus(){
    vpnCheck.vpnState.listen((state) {
      if (state == VPNState.connectedState) {
        if (kDebugMode) {
          print("VPN connected.");
        }
        setState(() {
          isVPN = true;
        });
      } else {
        if (kDebugMode) {
          print("VPN disconnected.");
        }
        setState(() {
          isVPN = false;
        });
      }
    });
  }
  appVersionStatus(){

    final newVersion = NewVersionChecker(
      iOSId: '',
      androidId: '',
    );

    statusCheck(newVersion);
  }

  statusCheck(NewVersionChecker newVersion) async {
    try {
      final status = await newVersion.getVersionStatus();

      if (status != null) {
        debugPrint(status.appStoreLink);
        debugPrint(status.localVersion);
        debugPrint(status.storeVersion);
        debugPrint(status.canUpdate.toString());

        if (status.canUpdate) {
          // new version available
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print(e.toString());
      }
    }
  }
}
