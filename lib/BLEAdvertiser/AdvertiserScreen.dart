import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

// If you have a helper, keep the import. It's not used in this variant.
// import 'BleAdvertiserHelper.dart';

enum TxPower { ultraLow, low, medium, high }

class BleAdvertiserScreen extends StatefulWidget {
  const BleAdvertiserScreen({super.key});

  @override
  State<BleAdvertiserScreen> createState() => _BleAdvertiserScreenState();
}

class _BleAdvertiserScreenState extends State<BleAdvertiserScreen> {
  static const _ch = MethodChannel('ble_peripheral');

  final _ble = FlutterReactiveBle();
  late final StreamSubscription<BleStatus> _statusSub;
  BleStatus _bleStatus = BleStatus.unknown;

  final _name = TextEditingController(text: 'My Phone');
  final _serviceUuid = TextEditingController(); // e.g. 0000180D-0000-1000-8000-00805F9B34FB
  final _mId = TextEditingController(text: '0x004C'); // Apple sample (hex or decimal)
  final _mData = TextEditingController(text: '01-02-03-04');

  bool _connectable = true;
  bool _includeDeviceName = true;
  bool _includeTxPower = false;
  TxPower _tx = TxPower.medium;

  bool _isAdvertising = false;
  String _statusMsg = '';

  @override
  void initState() {
    super.initState();
    _statusSub = _ble.statusStream.listen((s) {
      if (!mounted) return;
      setState(() => _bleStatus = s);
    });
    _bleStatus = _ble.status; // initial
  }

  @override
  void dispose() {
    _statusSub.cancel();
    _name.dispose();
    _serviceUuid.dispose();
    _mId.dispose();
    _mData.dispose();
    super.dispose();
  }

  Future<bool> _ensureBleAdvertisePermissions() async {
    if (!Platform.isAndroid) return true;

    final statuses = await [
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      // Add bluetoothScan if you also scan
    ].request();

    final granted = statuses.values.every((s) => s.isGranted);

    if (!granted) {
      final permanent = statuses.values.any((s) => s.isPermanentlyDenied);
      if (permanent) {
        await openAppSettings();
      }
    }

    return granted;
  }


  Uint8List _parseHex(String s) {
    final clean = s.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
    if (clean.isEmpty) return Uint8List(0);
    final bytes = <int>[];
    for (var i = 0; i < clean.length; i += 2) {
      final byteStr = clean.substring(i, i + 2);
      bytes.add(int.parse(byteStr, radix: 16));
    }
    return Uint8List.fromList(bytes);
  }

  int _parseManufacturerId(String input) {
    final trimmed = input.trim();
    if (trimmed.toLowerCase().startsWith('0x')) {
      return int.parse(trimmed.substring(2), radix: 16);
    }
    return int.parse(trimmed);
  }

  Future<void> _start() async {
    // 0) Permissions first (Android 12+)
    final havePerms = await _ensureBleAdvertisePermissions();
    if (!havePerms) {
      setState(() => _statusMsg = 'Permission denied: BLUETOOTH_ADVERTISE/CONNECT are required.');
      return;
    }

    // 1) Bluetooth must be ready
    if (_bleStatus != BleStatus.ready) {
      setState(() => _statusMsg = 'Bluetooth not ready (${_bleStatus.name}).');
      return;
    }

    try {
      // 2) Build args
      final args = <String, dynamic>{
        'localName': _name.text.trim().isEmpty ? null : _name.text.trim(),
        'serviceUuid': _serviceUuid.text.trim().isEmpty ? null : _serviceUuid.text.trim(),
        'manufacturerId': _mId.text.trim().isEmpty ? null : _parseManufacturerId(_mId.text),
        'manufacturerData': _mData.text.trim().isEmpty ? Uint8List(0) : _parseHex(_mData.text),
        'txPower': {
          TxPower.ultraLow: 0,
          TxPower.low: 1,
          TxPower.medium: 2,
          TxPower.high: 3,
        }[_tx],
        'connectable': _connectable,
        'includeDeviceName': _includeDeviceName,
        'includeTxPower': _includeTxPower,
      };

      // 3) Capability check
      final supported = await _ch.invokeMethod<bool>('isAdvertisingSupported') ?? false;
      if (!supported) {
        setState(() => _statusMsg = 'BLE advertising not supported on this device.');
        return;
      }

      // 4) Start advertising
      final ok = await _ch.invokeMethod<bool>('start', args) ?? false;
      setState(() {
        _isAdvertising = ok;
        _statusMsg = ok ? 'Advertising started.' : 'Failed to start advertising.';
      });
    } on PlatformException catch (e) {
      // Surface the native error code & message from Kotlin (START_FAIL/permission/etc.)
      setState(() => _statusMsg = 'Platform error [${e.code}]: ${e.message ?? e.details ?? 'unknown'}');
    } catch (e) {
      setState(() => _statusMsg = 'Error: $e');
    }
  }

  Future<void> _stop() async {
    try {
      await _ch.invokeMethod('stop');
      setState(() {
        _isAdvertising = false;
        _statusMsg = 'Advertising stopped.';
      });
    } catch (e) {
      setState(() => _statusMsg = 'Error stopping: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _bleStatus == BleStatus.ready;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('BLE Advertiser', style: TextStyle(color: Colors.white)),
          centerTitle: true,
          backgroundColor: Color(0xFF203A43),
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            labelColor: Colors.amber,
            indicatorColor: Colors.white54,
            physics: ScrollPhysics(),
            unselectedLabelColor: Colors.white,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: [
              Tab(icon: Icon(CupertinoIcons.dot_radiowaves_left_right), text: 'Advertiser'),
              Tab(icon: Icon(CupertinoIcons.info_circle), text: 'Info'),
            ],
          ),
        ),
        body: Stack(
          children: [
            // Subtle gradient background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0f172a), Color(0xFF1e293b), Color(0xFF0f172a)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            SafeArea(
              child: TabBarView(
                children: [
                  // -------- TAB 1: Advertiser UI --------
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          elevation: 8,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      ready ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                                      color: ready ? Colors.teal : Colors.red,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'BLE status: ${_bleStatus.name}',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    const Spacer(),
                                    Chip(
                                      avatar: Icon(
                                        _isAdvertising
                                            ? CupertinoIcons.dot_radiowaves_left_right
                                            : CupertinoIcons.pause,
                                        size: 18,
                                      ),
                                      label: Text(_isAdvertising ? 'Advertising' : 'Idle'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _name,
                                  decoration: const InputDecoration(
                                    labelText: 'Local name',
                                    hintText: 'e.g. My Phone',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _serviceUuid,
                                  decoration: const InputDecoration(
                                    labelText: 'Service UUID (optional)',
                                    hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _mId,
                                        decoration: const InputDecoration(
                                          labelText: 'Manufacturer ID',
                                          hintText: 'decimal or 0xFFFF',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _mData,
                                        decoration: const InputDecoration(
                                          labelText: 'Manufacturer data (hex)',
                                          hintText: 'e.g. 01-02-03-04',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    const Text('TX Power:'),
                                    ChoiceChip(
                                      label: const Text('Ultra-Low'),
                                      selected: _tx == TxPower.ultraLow,
                                      onSelected: (_) => setState(() => _tx = TxPower.ultraLow),
                                    ),
                                    ChoiceChip(
                                      label: const Text('Low'),
                                      selected: _tx == TxPower.low,
                                      onSelected: (_) => setState(() => _tx = TxPower.low),
                                    ),
                                    ChoiceChip(
                                      label: const Text('Medium'),
                                      selected: _tx == TxPower.medium,
                                      onSelected: (_) => setState(() => _tx = TxPower.medium),
                                    ),
                                    ChoiceChip(
                                      label: const Text('High'),
                                      selected: _tx == TxPower.high,
                                      onSelected: (_) => setState(() => _tx = TxPower.high),
                                    ),
                                    const SizedBox(width: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('Connectable'),
                                        Switch(
                                          value: _connectable,
                                          onChanged: (v) => setState(() => _connectable = v),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('Include name'),
                                        Switch(
                                          value: _includeDeviceName,
                                          onChanged: (v) => setState(() => _includeDeviceName = v),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('Include TX power (iOS)'),
                                        Switch(
                                          value: _includeTxPower,
                                          onChanged: (v) => setState(() => _includeTxPower = v),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: (!_isAdvertising && ready) ? _start : null,
                                        icon: const Icon(Icons.play_arrow),
                                        label: const Text('Start advertising'),
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          textStyle: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _isAdvertising ? _stop : null,
                                        icon: const Icon(Icons.stop),
                                        label: const Text('Stop'),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          textStyle: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _statusMsg,
                                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Tip: On iOS, advertising uses CoreBluetooth and may be limited in the background.',
                                  style: TextStyle(fontSize: 12, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // -------- TAB 2: Info (What/How/Architecture/Applications) --------
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 820),
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          elevation: 8,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(CupertinoIcons.info_circle),
                                  title: Text('What is a BLE Advertiser?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                                  subtitle: Text(
                                    'A BLE advertiser is a device that periodically broadcasts small packets (advertising events) over Bluetooth Low Energy. '
                                        'Other devices (centrals/scanners) can detect these packets without establishing a connection.',
                                  ),
                                ),
                                SizedBox(height: 12),
                                Text('How it works', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                                SizedBox(height: 8),
                                Text(
                                  '• The advertiser schedules advertising events on BLE channels 37/38/39.\n'
                                      '• Each event carries a payload (e.g., local name, service UUIDs, manufacturer data).\n'
                                      '• Scanners listen for these events; if interested, they may initiate a connection (if the advertiser is connectable).',
                                ),
                                SizedBox(height: 12),
                                Text('Architecture (High-level)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                                SizedBox(height: 8),
                                Text(
                                  'Android:\n'
                                      '  • App → BluetoothLeAdvertiser (framework) → Controller/Radio.\n'
                                      '  • Uses AdvertiseSettings & AdvertiseData for mode/tx power/payload.\n\n'
                                      'iOS:\n'
                                      '  • App → CoreBluetooth (CBPeripheralManager) → Controller/Radio.\n'
                                      '  • Uses startAdvertising with a dictionary of keys (local name, service UUIDs, manufacturer data).',
                                ),
                                SizedBox(height: 12),
                                Text('Typical application areas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                                SizedBox(height: 8),
                                Text(
                                  '• Proximity and presence (iBeacon/Eddystone-like beacons)\n'
                                      '• Offline discovery and device handoff\n'
                                      '• Access control / check-in kiosks\n'
                                      '• Retail engagement and asset tracking\n'
                                      '• Indoor navigation / wayfinding\n'
                                      '• Device-to-device bootstrapping before a connection',
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Notes & limits',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '• Advertising payload is small (≈31 bytes for legacy advertising).\n'
                                      '• Background advertising and power levels vary by platform and OEM.\n'
                                      '• On Android 12+, BLUETOOTH_ADVERTISE is required at runtime.',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
