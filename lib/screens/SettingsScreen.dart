import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // BLE status
  final _ble = FlutterReactiveBle();
  StreamSubscription<BleStatus>? _bleSub;
  BleStatus _bleStatus = BleStatus.unknown;

  // Model (persisted)
  bool _continuousScan = false;
  int _scanDurationSec = 10; // auto-stop after N sec
  ScanMode _scanMode = ScanMode.lowLatency;
  double _pathLossExponent = 2.0; // 2–4 typical

  bool _keepScreenOn = false;
  bool _enableHaptics = true;

  // Perms & meta
  String _version = '';
  bool _loading = true;

  // Permission flags (kept in state; do NOT await in build)
  bool _hasScan = false;
  bool _hasConnect = false;
  bool _hasLocation = false;

  @override
  void initState() {
    super.initState();
    _init();                 // load prefs, version, etc.
    _refreshPermissions();   // load permission states
    _bleSub = _ble.statusStream.listen((s) {
      if (!mounted) return;
      setState(() => _bleStatus = s);
    });

  }

  @override
  void dispose() {
    _bleSub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final info = await PackageInfo.fromPlatform();

    final stored = prefs.getInt('scanDurationSec');

    if (stored == null) {
      await prefs.setInt('scanDurationSec', 10); // seed default
    }

    print("Scan time is ${prefs.getInt("scanDurationSec")}");

    if (!mounted) return;
    setState(() {
      _continuousScan   = prefs.getBool('continuousScan') ?? false;
      _scanDurationSec  = prefs.getInt('scanDurationSec') ?? 10;
      _scanMode         = _scanModeFromString(prefs.getString('scanMode')) ?? ScanMode.lowLatency;
      _pathLossExponent = prefs.getDouble('pathLossExponent') ?? 2.0;

      _keepScreenOn     = prefs.getBool('keepScreenOn') ?? false;
      _enableHaptics    = prefs.getBool('enableHaptics') ?? true;

      _version = 'v${info.version} (${info.buildNumber})';
      _loading = false;
    });

    if (_keepScreenOn) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }


  Future<void> _refreshPermissions() async {
    final scan = await Permission.bluetoothScan.status;
    final connect = await Permission.bluetoothConnect.status;
    final loc = await Permission.locationWhenInUse.status;

    if (!mounted) return;
    setState(() {
      _hasScan = scan.isGranted;
      _hasConnect = connect.isGranted;
      _hasLocation = loc.isGranted;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('continuousScan', _continuousScan);
    await prefs.setInt('scanDurationSec', _scanDurationSec);
    await prefs.setString('scanMode', _scanMode.name);
    await prefs.setDouble('pathLossExponent', _pathLossExponent);
    await prefs.setBool('keepScreenOn', _keepScreenOn);
    await prefs.setBool('enableHaptics', _enableHaptics);
  }

  ScanMode? _scanModeFromString(String? s) {
    if (s == null) return null;
    for (final m in ScanMode.values) {
      if (m.name == s) return m;
    }
    return ScanMode.lowLatency;
  }

  // --------- Settings shortcuts ----------
  Future<void> _openBluetoothSettings() async {
    if (Platform.isAndroid) {
      const intent = AndroidIntent(action: 'android.settings.BLUETOOTH_SETTINGS');
      await intent.launch();
    } else if (Platform.isIOS) {
      // Apple blocks deep links to the Bluetooth page; try opening main Settings (may be ignored on some iOS versions)
      final uri = Uri.parse('App-Prefs:'); // or 'app-settings:'
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  Future<void> _openLocationSettings() async {
    if (Platform.isAndroid) {
      const intent = AndroidIntent(action: 'android.settings.LOCATION_SOURCE_SETTINGS');
      await intent.launch();
    } else if (Platform.isIOS) {
      final uri = Uri.parse('App-Prefs:');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  Future<void> _requestPermissions() async {
    // Request in one go
    final results = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse, // for Android 10–11 scan visibility
    ].request();

    // Recompute booleans
    await _refreshPermissions();

    // Snack if anything missing
    final anyDenied = results.values.any((s) => s.isDenied || s.isPermanentlyDenied || s.isRestricted);
    if (anyDenied && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Some permissions were denied. Scanning may be limited.')),
      );
    }
  }

  // --------- UI ----------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
          iconTheme: IconThemeData(
            color: Colors.white
          ),
          title: const Text('Settings',style: TextStyle(color: Colors.white),),
        backgroundColor: Color(0xFF2C5364),

      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // Bluetooth status card
          _SectionTitle('Bluetooth'),
          Card(

            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: _bleStatus == BleStatus.ready ? Color(0xFF2C5364) : cs.errorContainer,
            child: ListTile(
              leading: Icon(
                _bleStatus == BleStatus.ready ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                color: _bleStatus == BleStatus.ready ? Colors.white70: cs.onErrorContainer,
              ),
              title: Text(
                _bleStatus == BleStatus.ready ? 'Bluetooth is ON' : _statusText(_bleStatus),
                style: TextStyle(
                  color: _bleStatus == BleStatus.ready ? Colors.white70 : cs.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'This app listens for iBeacons.',
                style: TextStyle(
                  color: _bleStatus == BleStatus.ready ? Colors.white70 : cs.onErrorContainer,
                ),
              ),
              trailing: ElevatedButton.icon(
                onPressed: _openBluetoothSettings,
                icon: const Icon(Icons.settings_bluetooth),
                label: const Text('Open Settings'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _bleStatus == BleStatus.ready ? cs.onPrimaryContainer : cs.onErrorContainer,
                  foregroundColor: _bleStatus == BleStatus.ready ? cs.primaryContainer : cs.errorContainer,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Scanning
          _SectionTitle('Scanning'),
          _SwitchTile(
            title: 'Continuous scan',
            subtitle: 'Restart scanning automatically after each cycle',
            value: _continuousScan,
            onChanged: (v) {
              setState(() => _continuousScan = v);
              _savePrefs();
            },
          ),
          _DropdownTile<int>(
            title: 'Scan duration',
            subtitle: 'Auto-stop after this many seconds',
            value: _scanDurationSec,
            items: const [5, 10, 15, 20, 30, 60],
            itemLabel: (v) => '$v seconds',
            onChanged: (v) {
              if (v == null) return;
              setState(() => _scanDurationSec = v);
              _savePrefs();
            },
            icon: Icons.timer_outlined,
          ),
          _DropdownTile<ScanMode>(
            title: 'Scan mode',
            subtitle: 'Higher = faster discovery, more battery',
            value: _scanMode,
            items: const [ScanMode.lowPower, ScanMode.balanced, ScanMode.lowLatency],
            itemLabel: (m) {
              if (m == ScanMode.lowPower) return 'Low power';
              if (m == ScanMode.balanced) return 'Balanced';
              if (m == ScanMode.lowLatency) return 'Low latency';
              return m.name;
            },
            onChanged: (m) {
              if (m == null) return;
              setState(() => _scanMode = m);
              _savePrefs();
            },
            icon: Icons.speed,
          ),
          _SliderTile(
            title: 'Path-loss exponent',
            subtitle: 'Affects distance estimate (2.0 = open, 3–4 = indoors)',
            value: _pathLossExponent,
            min: 2.0,
            max: 4.0,
            divisions: 8,
            onChanged: (v) {
              setState(() => _pathLossExponent = double.parse(v.toStringAsFixed(1)));
            },
            onChangeEnd: (_) => _savePrefs(),
          ),

          const SizedBox(height: 16),

          // Permissions
          _SectionTitle('Permissions'),
          _PermTile(
            title: 'Bluetooth scan & connect',
            granted: (_hasScan && _hasConnect),
            onTap: _requestPermissions,
          ),
          _PermTile(
            title: 'Location (Android 10–11)',
            granted: _hasLocation,
            onTap: () async {
              await Permission.locationWhenInUse.request();
              await _refreshPermissions();
            },
          ),
          ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: const Text('Open location settings'),
            subtitle: const Text('On some phones, Location must be ON for BLE scans'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openLocationSettings,
          ),

          const SizedBox(height: 16),

          // App behaviour
          _SectionTitle('App'),
          _SwitchTile(
            title: 'Keep screen on',
            subtitle: 'Prevent the device from sleeping while scanning',
            value: _keepScreenOn,
            onChanged: (v) async {
              setState(() => _keepScreenOn = v);
              await _savePrefs();
              // For guaranteed behaviour, consider wakelock_plus
              // if (v) WakelockPlus.enable(); else WakelockPlus.disable();
            },
          ),
          _SwitchTile(
            title: 'Haptics',
            subtitle: 'Vibration feedback for actions',
            value: _enableHaptics,
            onChanged: (v) {
              setState(() => _enableHaptics = v);
              _savePrefs();
              if (v) HapticFeedback.selectionClick();
            },
          ),

          const SizedBox(height: 16),

          // About
          _SectionTitle('About'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Wireless'),
              subtitle: Text('BLE / iBeacon tools • $_version'),
            ),
          ),
        ],
      ),
    );
  }

  String _statusText(BleStatus s) {
    switch (s) {
      case BleStatus.ready:
        return 'Bluetooth is ON';
      case BleStatus.poweredOff:
        return 'Bluetooth is OFF';
      case BleStatus.unauthorized:
        return 'Bluetooth permission denied';
      case BleStatus.unsupported:
        return 'Bluetooth LE not supported';
      case BleStatus.locationServicesDisabled:
        return 'Location services disabled';
      default:
        return 'Bluetooth status unknown';
    }
  }
}

// ---------------- Support widgets ----------------

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: cs.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    Key? key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      value: value,
      onChanged: onChanged,
    );
  }
}

class _DropdownTile<T> extends StatelessWidget {
  final String title;
  final String? subtitle;
  final T value;
  final List<T> items;
  final String Function(T) itemLabel;
  final void Function(T?) onChanged;
  final IconData? icon;

  const _DropdownTile({
    Key? key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: icon != null ? Icon(icon) : null,
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: DropdownButton<T>(
        value: value,
        onChanged: onChanged,
        items: items
            .map((e) => DropdownMenuItem<T>(
          value: e,
          child: Text(itemLabel(e)),
        ))
            .toList(),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: cs.surfaceVariant.withOpacity(0.25),
    );
  }
}

class _SliderTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  const _SliderTile({
    Key? key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.onChangeEnd,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subtitle != null) Text(subtitle!),
          const SizedBox(height: 8),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: value.toStringAsFixed(1),
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ],
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: cs.surfaceVariant.withOpacity(0.25),
    );
  }
}

class _PermTile extends StatelessWidget {
  final String title;
  final bool granted;
  final VoidCallback onTap;

  const _PermTile({
    Key? key,
    required this.title,
    required this.granted,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ok = granted;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(ok ? Icons.verified_outlined : Icons.warning_amber_outlined,
            color: ok ? cs.primary : cs.error),
        title: Text(title),
        subtitle: Text(ok ? 'Granted' : 'Not granted'),
        trailing: TextButton(
          onPressed: onTap,
          child: Text(ok ? 'Recheck' : 'Request'),
        ),
      ),
    );
  }
}
