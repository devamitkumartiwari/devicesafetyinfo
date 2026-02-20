import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:device_safety_info/device_safety_info.dart';
import 'package:device_safety_info/new_version_check.dart';
import 'package:device_safety_info/vpn_check.dart';
import 'package:device_safety_info/vpn_state.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Device Safety Info',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const DeviceSafetyHome(),
    );
  }
}

class DeviceSafetyHome extends StatefulWidget {
  const DeviceSafetyHome({super.key});
  @override
  State<DeviceSafetyHome> createState() => _DeviceSafetyHomeState();
}

class _DeviceSafetyHomeState extends State<DeviceSafetyHome> {
  bool? isRootedDevice;
  bool? isScreenLock;
  bool? isRealDevice;
  bool? isExternalStorage;
  bool? isDeveloperMode;
  bool? isVPN;
  bool? isInstalledFromStore;
  bool? isHooked;

  bool _loading = false;
  final VPNCheck _vpnCheck = VPNCheck();
  late final Stream<VPNState> _vpnStream;

  @override
  void initState() {
    super.initState();
    _vpnStream = _vpnCheck.vpnState;
    _listenVpn();
    _refreshAll();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _listenVpn() {
    _vpnStream.listen((state) {
      final connected = state == VPNState.connectedState;
      if (mounted) {
        setState(() => isVPN = connected);
      }
    }, onError: (e) {
      if (kDebugMode) debugPrint('VPN listen error: $e');
    });
  }

  Future<void> _refreshAll() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
    });

    try {
      final futures = <Future<Object>>[
        DeviceSafetyInfo.isRootedDevice,
        DeviceSafetyInfo.isScreenLock,
        DeviceSafetyInfo.isRealDevice,
      ];

      if (Platform.isAndroid) {
        futures.addAll([
          DeviceSafetyInfo.isExternalStorage,
          DeviceSafetyInfo.isDeveloperMode,
        ]);
      }

      futures.add(DeviceSafetyInfo.isInstalledFromStore);
      futures.add(DeviceSafetyInfo.isHooked);

      final results = await Future.wait(futures);

      int idx = 0;
      setState(() {
        isRootedDevice = _boolFrom(results[idx++]);
        isScreenLock = _boolFrom(results[idx++]);
        isRealDevice = _boolFrom(results[idx++]);

        if (Platform.isAndroid) {
          isExternalStorage = _boolFrom(results[idx++]);
          isDeveloperMode = _boolFrom(results[idx++]);
        } else {
          isExternalStorage = null;
          isDeveloperMode = null;
        }

        isInstalledFromStore = _boolFrom(results[idx++]);
        isHooked = _boolFrom(results[idx++]);
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching device info: $e');
      if (mounted) {
        setState(() {
          isRootedDevice ??= false;
          isScreenLock ??= false;
          isRealDevice ??= true;
          isExternalStorage ??= (Platform.isAndroid ? false : null);
          isDeveloperMode ??= (Platform.isAndroid ? false : null);
          isInstalledFromStore ??= false;
          isHooked ??= false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  bool _boolFrom(Object? o) {
    if (o is bool) return o;
    if (o is int) return o != 0;
    if (o is String) return o.toLowerCase() == 'true';
    return false;
  }

  Future<void> _checkAppVersion() async {
    final checker = NewVersionChecker(iOSId: '', androidId: '');
    try {
      final status = await checker.getVersionStatus();
      if (!mounted) return;
      if (status != null && status.canUpdate) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('New version available: ${status.storeVersion}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App is up to date')),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Version check error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Version check failed')),
        );
      }
    }
  }

  Future<void> _showConfirmationDialog(String content, VoidCallback onConfirm) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Are you sure?'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(content),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Confirm'),
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _statusTile({
    required String title,
    required bool? value,
    String? subtitle,
    IconData? leadingIcon,
  }) {
    final bool unknown = value == null;
    final bool positive = value == true;

    final Color bgColor;
    final IconData displayIcon;
    final String label;
    if (unknown) {
      bgColor = Theme.of(context).colorScheme.surfaceContainerHighest;
      displayIcon = Icons.help_outline;
      label = 'Unknown';
    } else if (positive) {
      bgColor = Colors.green.shade50;
      displayIcon = leadingIcon ?? Icons.check_circle;
      label = 'Yes';
    } else {
      bgColor = Colors.red.shade50;
      displayIcon = leadingIcon ?? Icons.cancel;
      label = 'No';
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: bgColor,
          child: Icon(displayIcon, color: unknown ? Colors.orange : (positive ? Colors.green : Colors.red)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
          child: unknown
              ? Text('—', key: const ValueKey('unknown'))
              : Chip(
                  key: ValueKey(label),
                  side: BorderSide.none,
                  label: Text(label),
                  backgroundColor: positive ? Colors.green.shade100 : Colors.red.shade100,
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Safety Info'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _refreshAll,
            icon: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Version Check',
            onPressed: _checkAppVersion,
            icon: const Icon(Icons.system_update),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _refreshAll,
        icon: const Icon(Icons.search),
        label: const Text('Re-check'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Summary', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _refreshAll,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _statusTile(
                title: 'Device is rooted / jailbroken',
                value: isRootedDevice,
                leadingIcon: Icons.security,
                subtitle: 'Root/jailbreak increases risk — block if required.',
              ),
              _statusTile(
                title: 'Screen lock enabled',
                value: isScreenLock,
                leadingIcon: Icons.lock,
                subtitle: 'Secure lockscreen is recommended.',
              ),
              _statusTile(
                title: 'Real device (not emulator)',
                value: isRealDevice,
                leadingIcon: Icons.phone_android,
                subtitle: 'Emulators are often insecure / for testing only.',
              ),
              if (Platform.isAndroid) ...[
                _statusTile(
                  title: 'External storage available',
                  value: isExternalStorage,
                  leadingIcon: Icons.sd_storage,
                  subtitle: 'External storage access can be risky depending on app usage.',
                ),
                _statusTile(
                  title: 'Developer mode enabled',
                  value: isDeveloperMode,
                  leadingIcon: Icons.developer_mode,
                  subtitle: 'Developer options may expose debugging surfaces.',
                ),
              ],
              _statusTile(
                title: 'VPN connected',
                value: isVPN,
                leadingIcon: Icons.vpn_lock,
                subtitle: 'A VPN is active (useful for network security or suspicious traffic).',
              ),
              _statusTile(
                title: 'Installed from store',
                value: isInstalledFromStore,
                leadingIcon: Icons.storefront,
                subtitle: 'Install source: store vs sideload.',
              ),
              _statusTile(
                title: 'Device is hooked',
                value: isHooked,
                leadingIcon: Icons.bug_report,
                subtitle: 'Hooking frameworks like Frida or Xposed are present.',
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text('Actions', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => DeviceSafetyInfo.blockScreenshots(block: true),
                      icon: const Icon(Icons.screen_lock_portrait),
                      label: const Text('Block Screenshots'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => DeviceSafetyInfo.blockScreenshots(block: false),
                      icon: const Icon(Icons.screenshot),
                      label: const Text('Allow Screenshots'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => DeviceSafetyInfo.hideMenu(hide: true),
                      icon: const Icon(Icons.visibility_off),
                      label: const Text('Hide in Menu'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => DeviceSafetyInfo.hideMenu(hide: false),
                      icon: const Icon(Icons.visibility),
                      label: const Text('Show in Menu'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showConfirmationDialog(
                        'This will close the app if hooking is detected.',
                        () => DeviceSafetyInfo.checkHooked(exitProcessIfTrue: true),
                      ),
                      icon: const Icon(Icons.exit_to_app),
                      label: const Text('Check Hooked & Exit'),
                      style: ElevatedButton.styleFrom(foregroundColor: Colors.orange.shade800),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showConfirmationDialog(
                        'This will attempt to uninstall the app if hooking is detected.',
                        () => DeviceSafetyInfo.checkHooked(uninstallIfTrue: true),
                      ),
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Check Hooked & Uninstall'),
                      style: ElevatedButton.styleFrom(foregroundColor: Colors.red.shade800),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}
