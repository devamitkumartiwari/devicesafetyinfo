import 'dart:io';
import 'package:flutter/material.dart';
import 'package:device_safety_info/device_safety_info.dart';

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
  // --- Check results ---
  bool? isRootedDevice;
  bool? isScreenLock;
  bool? isRealDevice;
  bool? isExternalStorage;
  bool? isDeveloperMode;
  bool? isVPN;
  bool? isInstalledFromStore;
  bool? isHooked;
  bool? isScreenCaptured;
  bool? isDebuggerAttached;

  // --- Stream state ---
  bool _screenCaptureActive = false;
  int _screenshotCount = 0;

  bool _loading = false;

  final VPNCheck _vpnCheck = VPNCheck();
  late final Stream<VPNState> _vpnStream;

  @override
  void initState() {
    super.initState();
    _vpnStream = _vpnCheck.vpnState;
    _listenVpn();
    _listenScreenCapture();
    _listenScreenshots();
    _refreshAll();
  }

  @override
  void dispose() {
    _vpnCheck.dispose();
    super.dispose();
  }

  void _listenVpn() {
    _vpnStream.listen((state) {
      if (mounted) setState(() => isVPN = state == VPNState.connectedState);
    }, onError: (e) => debugPrint('VPN error: $e'));
  }

  void _listenScreenCapture() {
    DeviceSafetyInfo.onScreenCapturedChanged.listen((capturing) {
      if (mounted) setState(() => _screenCaptureActive = capturing);
    }, onError: (e) => debugPrint('Screen capture error: $e'));
  }

  void _listenScreenshots() {
    DeviceSafetyInfo.onScreenshotTaken.listen((_) {
      if (mounted) setState(() => _screenshotCount++);
    }, onError: (e) => debugPrint('Screenshot error: $e'));
  }

  Future<void> _refreshAll() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        DeviceSafetyInfo.isRootedDevice,
        DeviceSafetyInfo.isScreenLock,
        DeviceSafetyInfo.isRealDevice,
        DeviceSafetyInfo.isInstalledFromStore,
        DeviceSafetyInfo.isHooked,
        DeviceSafetyInfo.isScreenCaptured,
        DeviceSafetyInfo.isDebuggerAttached,
        if (Platform.isAndroid) DeviceSafetyInfo.isExternalStorage,
        if (Platform.isAndroid) DeviceSafetyInfo.isDeveloperMode,
      ]);

      if (!mounted) return;
      setState(() {
        isRootedDevice = results[0];
        isScreenLock = results[1];
        isRealDevice = results[2];
        isInstalledFromStore = results[3];
        isHooked = results[4];
        isScreenCaptured = results[5];
        isDebuggerAttached = results[6];
        if (Platform.isAndroid) {
          isExternalStorage = results[7];
          isDeveloperMode = results[8];
        } else {
          isExternalStorage = null;
          isDeveloperMode = null;
        }
      });
    } catch (e) {
      debugPrint('Error refreshing: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkAppVersion() async {
    final checker = NewVersionChecker(iOSId: '', androidId: '');
    try {
      final status = await checker.getVersionStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(status != null && status.canUpdate
            ? 'New version available: ${status.storeVersion}'
            : 'App is up to date'),
      ));
    } catch (e) {
      debugPrint('Version check error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Version check failed')),
        );
      }
    }
  }

  Future<void> _confirm(String message, VoidCallback onConfirm) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Are you sure?'),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Widget _tile({
    required String title,
    required bool? value,
    String? subtitle,
    IconData? icon,
  }) {
    final unknown = value == null;
    final positive = value == true;
    final color =
        unknown ? Colors.orange : (positive ? Colors.green : Colors.red);
    final bgColor = unknown
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : (positive ? Colors.green.shade50 : Colors.red.shade50);
    final displayIcon = unknown
        ? Icons.help_outline
        : (positive ? (icon ?? Icons.check_circle) : (icon ?? Icons.cancel));

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: bgColor,
          child: Icon(displayIcon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: unknown
            ? const Text('—')
            : Chip(
                side: BorderSide.none,
                label: Text(positive ? 'Yes' : 'No'),
                backgroundColor:
                    positive ? Colors.green.shade100 : Colors.red.shade100,
              ),
      ),
    );
  }

  Widget _streamTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: Chip(
          side: BorderSide.none,
          label: Text(value),
          backgroundColor: color.withValues(alpha: 0.15),
        ),
      ),
    );
  }

  Widget _sectionHeader(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(
          label,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Safety Info'),
        actions: [
          IconButton(
            tooltip: 'Version Check',
            onPressed: _checkAppVersion,
            icon: const Icon(Icons.system_update),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _refreshAll,
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              // --- Detection checks ---
              _sectionHeader('Detection'),
              _tile(
                title: 'Device is rooted / jailbroken',
                value: isRootedDevice,
                icon: Icons.security,
                subtitle:
                    'Root/jailbreak detected via native C + platform checks.',
              ),
              _tile(
                title: 'Real device (not emulator)',
                value: isRealDevice,
                icon: Icons.phone_android,
                subtitle: 'Emulators are often used for tampering.',
              ),
              _tile(
                title: 'Screen lock enabled',
                value: isScreenLock,
                icon: Icons.lock,
                subtitle: 'Secure lockscreen is recommended.',
              ),
              _tile(
                title: 'Installed from store',
                value: isInstalledFromStore,
                icon: Icons.storefront,
                subtitle: 'Sideloaded apps skip store security checks.',
              ),
              _tile(
                title: 'Hooking framework detected',
                value: isHooked,
                icon: Icons.bug_report,
                subtitle:
                    'Frida / Xposed / Substrate detected via FFI + platform.',
              ),
              _tile(
                title: 'Debugger attached',
                value: isDebuggerAttached,
                icon: Icons.adb,
                subtitle:
                    'TracerPid (Android) / sysctl P_TRACED (iOS) + platform check.',
              ),
              _tile(
                title: 'Screen is being captured',
                value: isScreenCaptured,
                icon: Icons.cast,
                subtitle: 'Screen recording or mirroring active.',
              ),
              if (Platform.isAndroid) ...[
                _tile(
                  title: 'Developer mode enabled',
                  value: isDeveloperMode,
                  icon: Icons.developer_mode,
                  subtitle:
                      'Android-only. Developer options expose debug surfaces.',
                ),
                _tile(
                  title: 'App on external storage',
                  value: isExternalStorage,
                  icon: Icons.sd_storage,
                  subtitle:
                      'Android-only. External storage can be tampered with.',
                ),
              ],

              // --- Live streams ---
              _sectionHeader('Live Streams'),
              _streamTile(
                title: 'VPN status',
                value: isVPN == true ? 'Connected' : 'Disconnected',
                icon: Icons.vpn_lock,
                color: isVPN == true ? Colors.orange : Colors.green,
                subtitle: 'Updates instantly on network change.',
              ),
              _streamTile(
                title: 'Screen recording stream',
                value: _screenCaptureActive ? 'Active' : 'Inactive',
                icon: Icons.screen_search_desktop,
                color: _screenCaptureActive ? Colors.red : Colors.green,
                subtitle: 'Real-time recording/mirroring detection.',
              ),
              _streamTile(
                title: 'Screenshots taken',
                value: '$_screenshotCount',
                icon: Icons.screenshot_monitor,
                color: _screenshotCount > 0 ? Colors.orange : Colors.blueGrey,
                subtitle: Platform.isAndroid
                    ? 'Android 34+: no permission. 24–33: needs READ_MEDIA_IMAGES.'
                    : 'iOS: no permission needed.',
              ),

              // --- Actions ---
              _sectionHeader('Actions'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () =>
                          DeviceSafetyInfo.blockScreenshots(block: true),
                      icon: const Icon(Icons.screen_lock_portrait),
                      label: const Text('Block Screenshots'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () =>
                          DeviceSafetyInfo.blockScreenshots(block: false),
                      icon: const Icon(Icons.screenshot),
                      label: const Text('Allow Screenshots'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => DeviceSafetyInfo.setRecentsOverlay(
                          argbColor: 0xFF1A1A2E),
                      icon: const Icon(Icons.blur_on),
                      label: const Text('Enable Recents Overlay'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => DeviceSafetyInfo.clearRecentsOverlay(),
                      icon: const Icon(Icons.blur_off),
                      label: const Text('Clear Recents Overlay'),
                    ),
                    if (Platform.isAndroid) ...[
                      ElevatedButton.icon(
                        onPressed: () => DeviceSafetyInfo.hideMenu(hide: true),
                        icon: const Icon(Icons.visibility_off),
                        label: const Text('Hide in Recents'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => DeviceSafetyInfo.hideMenu(hide: false),
                        icon: const Icon(Icons.visibility),
                        label: const Text('Show in Recents'),
                      ),
                    ],
                    ElevatedButton.icon(
                      onPressed: () => _confirm(
                        'This will exit the app if a hooking framework is detected.',
                        () => DeviceSafetyInfo.checkHooked(
                            exitProcessIfTrue: true),
                      ),
                      icon: const Icon(Icons.exit_to_app),
                      label: const Text('Check Hooked & Exit'),
                      style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.orange.shade800),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _confirm(
                        'This will attempt to uninstall the app if hooking is detected.',
                        () =>
                            DeviceSafetyInfo.checkHooked(uninstallIfTrue: true),
                      ),
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Check Hooked & Uninstall'),
                      style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.red.shade800),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _refreshAll,
        icon: const Icon(Icons.search),
        label: const Text('Re-check'),
      ),
    );
  }
}
