// lib/screens/BluetoothActivateScreen.dart
import 'dart:async';
import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:wireless/screens/MainScreen.dart';

class BluetoothActivateScreen extends StatefulWidget {
  const BluetoothActivateScreen({Key? key}) : super(key: key);

  @override
  State<BluetoothActivateScreen> createState() => _BluetoothActivateScreenState();
}

class _BluetoothActivateScreenState extends State<BluetoothActivateScreen>
    with WidgetsBindingObserver {
  final _ble = FlutterReactiveBle();
  StreamSubscription<BleStatus>? _sub;

  BleStatus _status = BleStatus.unknown;
  int? _androidSdk;

  // live snapshot of “are required permissions granted?”
  bool _permsMissing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    if (Platform.isAndroid) {
      final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
      _androidSdk = sdk;
    }

    // Take an initial permission snapshot
    await _refreshPermissionSnapshot();

    // Listen to BLE status and update UI / navigate when ready
    _sub = _ble.statusStream.listen((status) async {
      if (!mounted) return;
      setState(() => _status = status);

      // Keep permission snapshot fresh when status changes
      await _refreshPermissionSnapshot();

      if (status == BleStatus.ready) {
        // Small delay to avoid UI flicker & ensure system settled
        await Future.delayed(const Duration(milliseconds: 120));
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    });
  }

  Future<void> _refreshPermissionSnapshot() async {
    bool missing = false;
    if (Platform.isAndroid) {
      final sdk = _androidSdk ?? 33;
      if (sdk >= 31) {
        final scan = await Permission.bluetoothScan.status;
        final conn = await Permission.bluetoothConnect.status;
        missing = !scan.isGranted || !conn.isGranted;
      } else {
        final loc = await Permission.locationWhenInUse.status;
        missing = !loc.isGranted;
      }
    } else if (Platform.isIOS) {
      final bt = await Permission.bluetooth.status;
      missing = !bt.isGranted;
    }
    if (mounted) setState(() => _permsMissing = missing);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      HapticFeedback.selectionClick();
      // Re-check permissions after coming back from Settings / toggles
      await _refreshPermissionSnapshot();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  /* -------------------- Actions -------------------- */

  Future<void> _openBluetoothSettings() async {
    if (Platform.isAndroid) {
      const intent = AndroidIntent(action: 'android.settings.BLUETOOTH_SETTINGS');
      await intent.launch();
    } else if (Platform.isIOS) {
      // iOS can't deep-link to the Bluetooth pane; open this app's Settings instead.
      await openAppSettings();
      // (User can turn Bluetooth on from Control Center / Settings)
    }
  }

  Future<void> _openLocationSettingsIfAndroid() async {
    if (Platform.isAndroid) {
      const intent = AndroidIntent(action: 'android.settings.LOCATION_SOURCE_SETTINGS');
      await intent.launch();
    }
  }

  Future<void> _requestBlePermissions() async {
    if (Platform.isAndroid) {
      final sdk = _androidSdk ?? 33;
      if (sdk >= 31) {
        final results = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
        ].request();
        final denied = results.values.any((s) => s.isDenied);
        final permDenied = results.values.any((s) => s.isPermanentlyDenied);
        if (permDenied) {
          await openAppSettings();
        } else if (denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bluetooth permissions are required to proceed.')),
          );
        }
      } else {
        final s = await Permission.locationWhenInUse.request();
        if (s.isPermanentlyDenied) {
          await openAppSettings();
        } else if (!s.isGranted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location is required for Bluetooth scanning on this Android version.')),
          );
        }
      }
    } else if (Platform.isIOS) {
      final s = await Permission.bluetooth.request();
      await Future.delayed(const Duration(milliseconds: 300)); // settle CoreBluetooth
      if (s == PermissionStatus.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please allow Bluetooth to connect to your device.')),
        );
      } else if (s == PermissionStatus.restricted) {
        await openAppSettings();
      }
    }

    // Refresh the snapshot so the UI updates correctly
    await _refreshPermissionSnapshot();
  }

  /* -------------------- UI -------------------- */

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // PRIORITY:
    // 1) If Bluetooth is OFF -> show "Turn On Bluetooth" UI (DO NOT ask for perms yet).
    // 2) Else if some required permissions are missing -> show "Allow Bluetooth Access".
    // 3) Else (unknown/other) -> generic "Check status" action; READY auto-navigates.

    final isOff = _status == BleStatus.poweredOff;
    final needLocationServices = _status == BleStatus.locationServicesDisabled;
    final showPermsCta = !isOff && _permsMissing;

    final title = _titleForStatus(_status, forceOff: isOff, forcePerms: showPermsCta);
    final message = _messageForStatus(_status, showPermsCta);
    final icon = _iconForStatus(_status, forceOff: isOff, forcePerms: showPermsCta);

    return Scaffold(
      appBar: AppBar(title: const Text('Enable Bluetooth')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dynamic status card
            Card(
              color: cs.primaryContainer,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(icon, size: 32, color: cs.onPrimaryContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '$title\n$message',
                        style: TextStyle(color: cs.onPrimaryContainer),
                      ),
                    ),
                    _StatusChip(status: _status, permsMissing: _permsMissing),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Actions (respecting priority above)
            if (isOff) ...[
              // FilledButton.icon(
              //   onPressed: _openBluetoothSettings,
              //   icon: const Icon(Icons.settings_bluetooth),
              //   label: const Text('Open Bluetooth Settings'),
              // ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _openBluetoothSettings,
                icon: const Icon(Icons.power_settings_new),
                label: const Text('Turn Bluetooth On'),
              ),
            ] else if (needLocationServices) ...[
              FilledButton.icon(
                onPressed: _openLocationSettingsIfAndroid,
                icon: const Icon(Icons.location_on),
                label: const Text('Turn On Location Services'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _requestBlePermissions,
                icon: const Icon(Icons.lock_open_rounded),
                label: const Text('Check Permissions'),
              ),
            ] else if (showPermsCta) ...[
              FilledButton.icon(
                onPressed: _requestBlePermissions,
                icon: const Icon(Icons.lock_open_rounded),
                label: const Text('Allow Bluetooth Access'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: openAppSettings,
                icon: const Icon(Icons.settings_applications),
                label: const Text('Open App Settings'),
              ),
            ] else ...[
              FilledButton.icon(
                onPressed: _requestBlePermissions,
                icon: const Icon(Icons.sync),
                label: const Text('Check Bluetooth Status'),
              ),
            ],

            const SizedBox(height: 24),

            // Animation
            Expanded(
              child: Center(
                child: SizedBox(
                  height: 220,
                  child: Icon(Icons.bluetooth_disabled,size: 200,color: Colors.grey,)
                ),
              ),
            ),

            if (Platform.isAndroid)
              Text(
                'Tip: Some Android phones require Location Services ON to receive BLE advertisements.',
                style: TextStyle(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }

  String _titleForStatus(BleStatus s, {required bool forceOff, required bool forcePerms}) {
    if (forceOff) return 'Bluetooth is turned off';
    if (forcePerms) return 'Bluetooth permission required';
    switch (s) {
      case BleStatus.ready:
        return 'Bluetooth is ready';
      case BleStatus.unauthorized:
        return 'Bluetooth permission required';
      case BleStatus.locationServicesDisabled:
        return 'Location services are off';
      case BleStatus.unsupported:
        return 'Bluetooth LE not supported';
      case BleStatus.unknown:
      case BleStatus.poweredOff:
      default:
        return 'Checking Bluetooth…';
    }
  }

  String _messageForStatus(BleStatus s, bool showPermsCta) {
    if (showPermsCta) {
      if (Platform.isIOS) {
        return 'Allow Bluetooth access in the permission prompt or in Settings.';
      }
      final sdk = _androidSdk ?? 33;
      return sdk >= 31
          ? 'Allow Bluetooth Scan & Connect to use BLE.'
          : 'Allow Location while using the app to scan for BLE.';
    }

    switch (s) {
      case BleStatus.ready:
        return 'You can start scanning for nearby devices.';
      case BleStatus.poweredOff:
        return 'Please turn it on to scan for devices.';
      case BleStatus.unauthorized:
      // We only show this branch when not "forcePerms"; keep generic
        return 'The app may need permission to use Bluetooth.';
      case BleStatus.locationServicesDisabled:
        return 'Some Android devices require Location services ON for BLE scanning.';
      case BleStatus.unsupported:
        return 'This device cannot use Bluetooth Low Energy.';
      case BleStatus.unknown:
      default:
        return 'Please wait…';
    }
  }

  IconData _iconForStatus(BleStatus s, {required bool forceOff, required bool forcePerms}) {
    if (forceOff) return Icons.bluetooth_disabled_rounded;
    if (forcePerms) return Icons.lock_rounded;
    switch (s) {
      case BleStatus.ready:
        return Icons.bluetooth_connected_rounded;
      case BleStatus.unauthorized:
        return Icons.lock_rounded;
      case BleStatus.locationServicesDisabled:
        return Icons.location_off_rounded;
      case BleStatus.unsupported:
        return Icons.block_rounded;
      case BleStatus.unknown:
      case BleStatus.poweredOff:
      default:
        return Icons.sync_rounded;
    }
  }
}

/* ---------- Small chip showing current status & perms ---------- */

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.permsMissing});
  final BleStatus status;
  final bool permsMissing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    String text;
    Color bg;

    if (status == BleStatus.poweredOff) {
      text = 'OFF';
      bg = Colors.orange;
    } else if (status == BleStatus.ready) {
      text = 'READY';
      bg = Colors.green;
    } else if (status == BleStatus.locationServicesDisabled) {
      text = 'NO GPS';
      bg = Colors.deepOrange;
    } else if (status == BleStatus.unsupported) {
      text = 'UNSUP';
      bg = Colors.grey;
    } else if (permsMissing) {
      text = 'NO PERM';
      bg = Colors.redAccent;
    } else {
      text = '…';
      bg = cs.outlineVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
