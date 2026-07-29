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
  bool? isAnyAccessibilityServiceEnabled;
  PlayProtectStatus? playProtectStatus;

  // --- Stream state ---
  bool _screenCaptureActive = false;
  int _screenshotCount = 0;
  int _overlayAttackCount = 0;
  int _clipboardChangeCount = 0;
  int _idleTimeoutCount = 0;

  // --- Demo results ---
  bool? _malwareCheckKnownGood; // com.android.settings — expected: installed
  bool?
      _malwareCheckKnownBad; // com.example.known.malware — expected: not installed
  List<RiskFlag>? _riskFlags;

  // --- Action toggle state ---
  bool _blockScreenshots = false;
  bool _recentsOverlayEnabled = false;
  bool _hideInRecents = false;
  bool _blockTouchesWhenObscured = false;

  bool _loading = false;

  final VPNCheck _vpnCheck = VPNCheck();
  late final Stream<VPNState> _vpnStream;

  final TextEditingController _clipboardController =
      TextEditingController(text: '123456');
  final TextEditingController _iocController =
      TextEditingController(text: 'sub.evil.com');
  String? _iocResult;

  @override
  void initState() {
    super.initState();
    _vpnStream = _vpnCheck.vpnState;
    _listenVpn();
    _listenScreenCapture();
    _listenScreenshots();
    _listenClipboardChanges();
    if (Platform.isAndroid) _listenOverlayAttacks();
    IOCDomainBlocker.updateBlocklist(['evil.com', '*.evil.com']);
    _refreshAll();
  }

  @override
  void dispose() {
    _vpnCheck.dispose();
    _clipboardController.dispose();
    _iocController.dispose();
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

  void _listenOverlayAttacks() {
    DeviceSafetyInfo.onOverlayAttackDetected.listen((_) {
      if (mounted) setState(() => _overlayAttackCount++);
    }, onError: (e) => debugPrint('Overlay attack stream error: $e'));
  }

  void _listenClipboardChanges() {
    DeviceSafetyInfo.onClipboardChanged.listen((_) {
      if (mounted) setState(() => _clipboardChangeCount++);
    }, onError: (e) => debugPrint('Clipboard stream error: $e'));
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

      // Fetched separately: different return type (PlayProtectStatus, not bool) than the
      // Future.wait batch above.
      if (Platform.isAndroid) {
        final anyAccessibility =
            await DeviceSafetyInfo.isAnyAccessibilityServiceEnabled;
        final protectStatus = await DeviceSafetyInfo.playProtectStatus;
        if (mounted) {
          setState(() {
            isAnyAccessibilityServiceEnabled = anyAccessibility;
            playProtectStatus = protectStatus;
          });
        }
      }
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

  // --- Action toggle handlers ---

  Future<void> _toggleBlockScreenshots(bool value) async {
    await DeviceSafetyInfo.blockScreenshots(block: value);
    if (mounted) setState(() => _blockScreenshots = value);
  }

  Future<void> _toggleRecentsOverlay(bool value) async {
    if (value) {
      await DeviceSafetyInfo.setRecentsOverlay(argbColor: 0xFF1A1A2E);
    } else {
      await DeviceSafetyInfo.clearRecentsOverlay();
    }
    if (mounted) setState(() => _recentsOverlayEnabled = value);
  }

  Future<void> _toggleHideInRecents(bool value) async {
    await DeviceSafetyInfo.hideMenu(hide: value);
    if (mounted) setState(() => _hideInRecents = value);
  }

  Future<void> _toggleBlockTouchesWhenObscured(bool value) async {
    try {
      await DeviceSafetyInfo.blockTouchesWhenObscured(block: value);
      if (mounted) setState(() => _blockTouchesWhenObscured = value);
    } catch (e) {
      // Throws by design on iOS — overlay attacks are structurally impossible there.
      debugPrint('blockTouchesWhenObscured error: $e');
    }
  }

  Future<void> _copySensitiveToClipboard() async {
    await DeviceSafetyInfo.copyToClipboard(
      _clipboardController.text,
      sensitive: true,
      autoClear: const Duration(seconds: 30),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied — clears automatically in 30s')),
      );
    }
  }

  Future<void> _clearClipboard() async {
    await DeviceSafetyInfo.clearClipboard();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clipboard cleared')),
      );
    }
  }

  void _checkIocDomain() {
    final host = _iocController.text.trim();
    final blocked = IOCDomainBlocker.isBlocked(host);
    setState(() => _iocResult = blocked ? 'Blocked' : 'Not blocked');
  }

  Future<void> _runMalwareChecks() async {
    final knownGood =
        await MalwarePackageDetector.isPackageInstalled('com.android.settings');
    final knownBad = await MalwarePackageDetector.isPackageInstalled(
        'com.example.known.malware');
    if (mounted) {
      setState(() {
        _malwareCheckKnownGood = knownGood;
        _malwareCheckKnownBad = knownBad;
      });
    }
  }

  Future<void> _evaluateRisk() async {
    final flags = await RiskSummary.evaluate();
    if (mounted) setState(() => _riskFlags = flags);
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

  Widget _switchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    String? subtitle,
    IconData? icon,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        secondary: icon != null ? Icon(icon) : null,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle != null ? Text(subtitle) : null,
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _demoCard({required List<Widget> children}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      );

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
    return IdleTimeoutGuard(
      timeout: const Duration(seconds: 30),
      onTimeout: () => setState(() => _idleTimeoutCount++),
      child: Scaffold(
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
                  _tile(
                    title: 'Accessibility service enabled',
                    value: isAnyAccessibilityServiceEnabled,
                    icon: Icons.accessibility_new,
                    subtitle:
                        'Android-only. A common abuse vector for screen-reading malware.',
                  ),
                  _streamTile(
                    title: 'Play Protect status',
                    value: switch (playProtectStatus) {
                      PlayProtectStatus.enabled => 'Enabled',
                      PlayProtectStatus.disabled => 'Disabled',
                      _ => 'Unknown',
                    },
                    icon: Icons.shield_outlined,
                    color: playProtectStatus == PlayProtectStatus.disabled
                        ? Colors.red
                        : Colors.green,
                    subtitle:
                        'Android-only. Reads the underlying OS setting directly.',
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
                _streamTile(
                  title: 'Idle timeouts fired',
                  value: '$_idleTimeoutCount',
                  icon: Icons.timer_outlined,
                  color: Colors.blueGrey,
                  subtitle:
                      'IdleTimeoutGuard wraps this screen — fires after 30s with no touches.',
                ),

                // --- Actions (ON/OFF toggles) ---
                _sectionHeader('Actions'),
                _switchTile(
                  title: 'Block Screenshots',
                  value: _blockScreenshots,
                  onChanged: _toggleBlockScreenshots,
                  icon: Icons.screen_lock_portrait,
                  subtitle: 'Prevents screenshots and screen recordings.',
                ),
                _switchTile(
                  title: 'Recents Overlay',
                  value: _recentsOverlayEnabled,
                  onChanged: _toggleRecentsOverlay,
                  icon: Icons.blur_on,
                  subtitle: 'Solid color overlay in the app switcher.',
                ),
                if (Platform.isAndroid) ...[
                  _switchTile(
                    title: 'Hide in Recents',
                    value: _hideInRecents,
                    onChanged: _toggleHideInRecents,
                    icon: Icons.visibility_off,
                    subtitle: 'Android-only. Hides app from recent apps list.',
                  ),
                  _switchTile(
                    title: 'Block Touches When Obscured',
                    value: _blockTouchesWhenObscured,
                    onChanged: _toggleBlockTouchesWhenObscured,
                    icon: Icons.layers_clear,
                    subtitle:
                        'Android-only. Drops touches while another app overlays yours.',
                  ),
                ],

                // --- Overlay & Clipboard ---
                _sectionHeader('Overlay & Clipboard'),
                if (Platform.isAndroid)
                  _streamTile(
                    title: 'Overlay attacks detected',
                    value: '$_overlayAttackCount',
                    icon: Icons.layers,
                    color: _overlayAttackCount > 0 ? Colors.red : Colors.green,
                    subtitle:
                        'Touches received while obscured by another app\'s overlay.',
                  ),
                _streamTile(
                  title: 'Clipboard changes',
                  value: '$_clipboardChangeCount',
                  icon: Icons.content_paste,
                  color: Colors.blueGrey,
                  subtitle:
                      'Fires for changes from any app, not just this one.',
                ),
                _demoCard(children: [
                  const Text('Clipboard demo',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _clipboardController,
                    decoration: const InputDecoration(
                      labelText: 'Text to copy',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _copySensitiveToClipboard,
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy (sensitive, 30s auto-clear)'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _clearClipboard,
                        icon: const Icon(Icons.delete_sweep),
                        label: const Text('Clear Clipboard'),
                      ),
                    ],
                  ),
                ]),

                // --- IOC Domain Check ---
                _sectionHeader('IOC Domain Check'),
                _demoCard(children: [
                  Text(
                    'Seeded with: evil.com, *.evil.com',
                    style: TextStyle(
                        fontSize: 12, color: Theme.of(context).hintColor),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _iocController,
                    decoration: const InputDecoration(
                      labelText: 'Hostname',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _checkIocDomain,
                        icon: const Icon(Icons.search),
                        label: const Text('Check Domain'),
                      ),
                      if (_iocResult != null) ...[
                        const SizedBox(width: 12),
                        Text(
                          _iocResult!,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _iocResult == 'Blocked'
                                ? Colors.red
                                : Colors.green,
                          ),
                        ),
                      ],
                    ],
                  ),
                ]),

                // --- Malware & Risk ---
                _sectionHeader('Malware & Risk'),
                if (Platform.isAndroid)
                  _demoCard(children: [
                    const Text('Malware package check',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      'Both package names must be declared in AndroidManifest.xml <queries> —'
                      ' see this example app\'s manifest.',
                      style: TextStyle(
                          fontSize: 12, color: Theme.of(context).hintColor),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _runMalwareChecks,
                      icon: const Icon(Icons.search),
                      label: const Text('Run Checks'),
                    ),
                    if (_malwareCheckKnownGood != null) ...[
                      const SizedBox(height: 8),
                      Text(
                          'com.android.settings: ${_malwareCheckKnownGood! ? "Installed" : "Not installed"}'),
                      Text(
                          'com.example.known.malware: ${_malwareCheckKnownBad! ? "Installed" : "Not installed"}'),
                    ],
                  ]),
                _demoCard(children: [
                  const Text('Risk summary',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    'Aggregates rooted/hooked/debugger/screen-capture/VPN/screen-lock checks.',
                    style: TextStyle(
                        fontSize: 12, color: Theme.of(context).hintColor),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _evaluateRisk,
                    icon: const Icon(Icons.assessment_outlined),
                    label: const Text('Evaluate Risk'),
                  ),
                  if (_riskFlags != null) ...[
                    const SizedBox(height: 8),
                    if (_riskFlags!.isEmpty)
                      const Text('No active risk flags.',
                          style: TextStyle(color: Colors.green))
                    else
                      ..._riskFlags!.map((flag) => Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('• ${flag.title}: ${flag.description}'),
                          )),
                  ],
                ]),

                // --- Danger Zone ---
                _sectionHeader('Danger Zone'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
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
                          () => DeviceSafetyInfo.checkHooked(
                              uninstallIfTrue: true),
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
      ),
    );
  }
}
