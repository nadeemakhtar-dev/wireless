import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wireless/helpers/DeviceTileExpandable.dart';
import 'package:wireless/screens/AboutDevice.dart';
import 'package:wireless/screens/AboutScreen.dart';
import 'package:wireless/screens/FeedbackScreen.dart';
import 'package:wireless/screens/FilterScreen.dart';
import 'package:wireless/screens/HelpScreen.dart';
import 'package:wireless/screens/SessionLogs.dart';
import 'package:wireless/screens/SettingsScreen.dart';
import 'package:wireless/screens/TutorialScreen.dart';
import 'package:wireless/services/ReactiveBleManager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wireless/utils/Drawer.dart';

import '../model/FavouriteModel.dart';
import '../services/PermissionCoordinator.dart';
import '../services/SharedPreferences.dart';
import '../utils/ElegantTile.dart';
import '../widgets/CupertinoInfoSheet.dart';
import 'DeviceScreen.dart';
import 'QrCodeScanScreen.dart';
import 'RadarScanScreen.dart';
import 'TabScreens/FavouritesTab.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin{

  late final ReactiveBleManager ble;
  StreamSubscription<DiscoveredDevice>? _scanSub;
  final _devices = <String, DiscoveredDevice>{};
  bool _scanning = false;
  Timer? _scanTimer;

  final _colorMap = <String, Color>{};
  final _random = Random();
  bool allPermissionsGranted = false;

  bool _checkingPerms = false;  // prevent double permission flows

  // NEW: tab controller
  late final TabController _tabController;
  // ---- SharedPreferences keys (must match FilterScreen) ----
  static const _kByNameEnabled        = 'byNameEnabled';
  static const _kByRssiEnabled        = 'byRssiEnabled';
  static const _kByServiceUuidEnabled = 'byServiceUuidEnabled';
  static const _kFavoritesOnly        = 'favoritesOnly';
  static const _kNameText             = 'nameText';
  static const _kServiceUuidText      = 'serviceUuidText';
  static const _kRssiValue            = 'rssiValue';
  static const _kFavEnabledSet        = 'favoriteDevicesEnabledSet'; // List<String>
  static const _kFavDevicesList       = 'favoriteDevicesList';       // List<String> (optional, for info)
  static const _kScanDuration         = 'scanDuration';              // Int seconds

  // ---- Loaded filter values ----
  bool _fByName = false;
  bool _fByRssi = false;
  bool _fByUuid = false;
  bool _fFavoritesOnly = false;

  String _fName = '';
  String _fServiceUuid = '';
  int _fRssiThreshold = -100;

  Set<String> _favSelected = {};   // (names or ids depending on how you save them)
  List<String> _favAll = [];       // optional info/diagnostics

  int _scanDurationSec = 15;       // default, overridden by prefs


  @override
  void initState() {
    super.initState();
    ble = ReactiveBleManager(FlutterReactiveBle());

    // Load scan duration + filters up front
    _loadScanSettings();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 150));
      if (mounted) _checkPermissionsAndStart();
    });

    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
  }

  Future<void> _loadScanSettings() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _fByName        = prefs.getBool(_kByNameEnabled)        ?? false;
      _fByRssi        = prefs.getBool(_kByRssiEnabled)        ?? false;
      _fByUuid        = prefs.getBool(_kByServiceUuidEnabled) ?? false;
      _fFavoritesOnly = prefs.getBool(_kFavoritesOnly)        ?? false;

      _fName          = prefs.getString(_kNameText)           ?? '';
      _fServiceUuid   = prefs.getString(_kServiceUuidText)    ?? '';
      _fRssiThreshold = (prefs.getDouble(_kRssiValue) ?? -100.0).round();

      _favSelected    = (prefs.getStringList(_kFavEnabledSet) ?? const <String>[]).toSet();
      _favAll         = prefs.getStringList(_kFavDevicesList) ?? const <String>[];

      _scanDurationSec = prefs.getInt(_kScanDuration) ?? 15;
    });

    debugPrint("[ScanScreen] Loaded filters: "
        "byName=$_fByName('$_fName'), byRssi=$_fByRssi($_fRssiThreshold dBm), "
        "byUuid=$_fByUuid('$_fServiceUuid'), favoritesOnly=$_fFavoritesOnly, "
        "favSelected=$_favSelected, scanDuration=${_scanDurationSec}s");
  }


  bool _passesFilters(DiscoveredDevice d) {
    // Normalize name/id for comparisons
    final name = (d.name.isEmpty ? '' : d.name).toLowerCase();
    final id   = d.id.toLowerCase();

    // 1) Favorites: if enabled, device must match one of selected favorites.
    if (_fFavoritesOnly) {
      // You can decide what you store in _favSelected: names, ids, or both.
      // Here, we accept a match if either the name or id equals an entry.
      final lowerSet = _favSelected.map((e) => e.toLowerCase()).toSet();
      if (!lowerSet.contains(name) && !lowerSet.contains(id)) {
        return false;
      }
    }

    // 2) By Name
    if (_fByName) {
      final q = _fName.toLowerCase().trim();
      if (q.isNotEmpty && !name.contains(q)) return false;
    }

    // 3) By RSSI (device must be >= threshold)
    if (_fByRssi) {
      if (d.rssi < _fRssiThreshold) return false;
    }

    // 4) By Service UUID
    if (_fByUuid) {
      final target = _normalizeUuid(_fServiceUuid);
      if (target == null) return false; // invalid target; reject all
      final anyMatch = d.serviceUuids.any((u) {
        final s = _normalizeUuid(u.toString());
        return s != null && s == target;
      });
      if (!anyMatch) return false;
    }

    return true;
  }

  // Accepts 16/32/128-bit, strips braces/dashes, lowercases
  String? _normalizeUuid(String? raw) {
    if (raw == null) return null;
    final t = raw.trim().toLowerCase();
    if (t.isEmpty) return null;
    final hex = t.replaceAll(RegExp(r'[^0-9a-f]'), '');
    if (hex.isEmpty) return null;

    // 16/32-bit -> expand? For comparison we can just compare normalized without dashes.
    // If you need strict 128-bit equivalence, expand using base UUID if desired.
    return hex;
  }



  //
  // Future<void> initService() async{
  //   if(mounted) {
  //     final prefs = await SharedPreferences.getInstance();
  //     print("Scan Screen scan duration is ${prefs.getInt("scanDuration")}");
  //    setState(() {
  //      scanDurationTime = prefs.getInt("scanDuration") ?? 10;
  //    });
  //   }
  //
  //
  //
  // }

  Future<void> _checkPermissionsAndStart() async {
    if (_checkingPerms) return;
    _checkingPerms = true;
    try {
      await _ensurePermissions();
      if (!mounted) return;
      if (allPermissionsGranted) {
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          _startScan();
        });
      } else {
        Fluttertoast.showToast(
          msg: "Permissions not granted",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.redAccent,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    } finally {
      _checkingPerms = false;
    }
  }




  Future<void> _ensurePermissions() async {
    // Build candidate list
    final candidates = <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.camera,
    ];

    if (Platform.isAndroid) {
      final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
      if (sdk <= 30) {
        candidates.add(Permission.locationWhenInUse);
      }
    }

    // 1) Check current statuses first
    final current = await PermissionCoordinator.instance.statuses(candidates);
    final missing = current.entries
        .where((e) => !e.value.isGranted)
        .map((e) => e.key)
        .toList();

    if (missing.isEmpty) {
      allPermissionsGranted = true;
      return;
    }

    // 2) Request only missing, serialized + retry protected
    final results = await PermissionCoordinator.instance.request(missing);

    // 3) Combine & compute final outcome
    final combined = Map<Permission, PermissionStatus>.from(current)..addAll(results);
    combined.forEach((p, s) => debugPrint('> $p => $s'));
    final permanentlyDenied = combined.values.any((s) => s.isPermanentlyDenied);
    allPermissionsGranted = combined.values.every((s) => s.isGranted);

    if (permanentlyDenied) {
      await openAppSettings();
      // Recheck silently after returning
      final after = await PermissionCoordinator.instance.statuses(candidates);
      allPermissionsGranted = after.values.every((s) => s.isGranted);
    }
  }

  Future<Map<String, String>> _collectDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final a = await deviceInfo.androidInfo;
      return {
        'Device': '${a.manufacturer} ${a.model}',
        'Android': '${a.version.release} (SDK ${a.version.sdkInt})',
        'Brand': a.brand ?? '',
        'Hardware': a.hardware ?? '',
        'Product': a.product ?? '',
        'Device Code': a.device ?? '',
        if (a.id?.isNotEmpty == true) 'Build ID': a.id!,
        'Physical': a.isPhysicalDevice ? 'Yes' : 'No',
      }..removeWhere((_, v) => v.isEmpty);
    } else if (Platform.isIOS) {
      final i = await deviceInfo.iosInfo;
      // Some fields can be null depending on iOS
      final machine = i.utsname.machine ?? '';
      return {
        'Device': i.name ?? i.model ?? 'iPhone',
        'iOS': i.systemVersion ?? '',
        'Model': i.model ?? '',
        if (machine.isNotEmpty) 'Identifier': machine,
        'System': i.systemName ?? 'iOS',
        'Physical': i.isPhysicalDevice ? 'Yes' : 'No',
        if ((i.identifierForVendor ?? '').isNotEmpty)
          'Vendor ID': i.identifierForVendor!,
      }..removeWhere((_, v) => v.isEmpty);
    }

    return {'Platform': 'Unsupported'};
  }

  Future<void> _showDeviceInfoSheet() async {
    final info = await _collectDeviceInfo();

    if (!mounted) return;

    showCupertinoModalPopup(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => CupertinoInfoSheet(
        title: 'This Device',
        info: info,
        primaryColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }
  final Map<String, String> _displayNames = {};



  void _startScan() async {
    if (!mounted || _scanning) return;

    // Refresh filters/duration in case user changed them recently
    await _loadScanSettings();

    final status = await ble.currentStatus;
    if (status != BleStatus.ready) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please turn on Bluetooth to scan for devices")),
      );
      return;
    }

    _devices.clear();
    _colorMap.clear();
    setState(() => _scanning = true);

    _scanSub?.cancel();
    _scanTimer?.cancel();

    debugPrint("[ScanScreen] Starting scan with filters: "
        "favoritesOnly=$_fFavoritesOnly, favSelected=$_favSelected, "
        "byName=$_fByName('$_fName'), byRssi=$_fByRssi($_fRssiThreshold), "
        "byUuid=$_fByUuid('$_fServiceUuid'); duration=${_scanDurationSec}s");

    _scanSub = ble.scan().listen(
          (d) {
        if (!mounted) return;

        // Apply filters
        if (!_passesFilters(d)) {
          // debugPrint("[ScanScreen] Filtered OUT: ${d.name} (${d.id}) rssi=${d.rssi}");
          return;
        }

        // Keep
        setState(() {
          _devices[d.id] = d;
          _colorMap.putIfAbsent(
            d.id,
                () => Colors.primaries[_random.nextInt(Colors.primaries.length)],
          );
        });
      },
      onError: (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan error: $e')),
        );
        setState(() => _scanning = false);
      },
      onDone: () {
        if (!mounted) return;
        setState(() => _scanning = false);
      },
    );

    // Auto-stop after persisted duration
    _scanTimer = Timer(Duration(seconds: _scanDurationSec), () {
      _stopScan();
      if (!mounted) return;
      Fluttertoast.showToast(
        msg: "Scan Completed..",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: const Color(0xFF203A43),
        textColor: Colors.white,
        fontSize: 16.0,
      );
    });
  }




  // Opens a QR camera screen, parses device id, then navigates to DeviceScreen
  Future<void> _scanQrAndConnect() async {
    // Ensure camera permission (defensive)
    // final cam = await Permission.camera.request();
    // if (!cam.isGranted) {
    //   if (!mounted) return;
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(content: Text('Camera permission is required to scan')),
    //   );
    //   return;
    // }

    // Open scanner and wait for a single code result
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );

    if (!mounted || code == null || code.isEmpty) return;

    final parsed = _parseDeviceIdFromQr(code);
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR does not contain a valid BLE device id')),
      );
      return;
    }

    final deviceId = parsed.$1;
    final deviceName = parsed.$2;

    // If device already discovered, just navigate
    final known = _devices[deviceId];
    if (known != null) {
      _stopScan();
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DeviceScreen(device: known, ble: ble),
        ),
      );
      return;
    }

    // Otherwise create a placeholder DiscoveredDevice and navigate.
    // DeviceScreen will handle the actual connect flow, as in your current code.
    final placeholder = DiscoveredDevice(
      id: deviceId,
      name: (deviceName != null && deviceName.trim().isNotEmpty) ? deviceName : deviceId,// 👈 use provided name or ID
      rssi: 0,
      serviceData: const {},
      manufacturerData: Uint8List(0),
      serviceUuids: const [],
    );

    _stopScan();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DeviceScreen(device: placeholder, ble: ble),
      ),
    );
  }

  /// Accepts raw MAC (Android), UUID (iOS), or payloads like:
  ///   ble:AA:BB:CC:DD:EE:FF
  ///   {"id":"AA:BB:CC:DD:EE:FF","name":"MyTag"}
  /// Returns (deviceId, optionalName) or null if not recognized

  (String, String?)? _parseDeviceIdFromQr(String raw) {
    try {
      final code = raw.trim();
      if (code.isEmpty) return null;

      final mac   = RegExp(r'([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}');
      final uuid  = RegExp(r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}');
      final blePrefix = RegExp(r'^ble:', caseSensitive: false);

      String? pickId(String s) {
        final m1 = mac.firstMatch(s);
        if (m1 != null) return m1.group(0)!;
        final m2 = uuid.firstMatch(s);
        if (m2 != null) return m2.group(0)!;
        return null;
      }

      // 1) JSON payload
      if (code.startsWith('{')) {
        final obj = jsonDecode(code);
        if (obj is Map) {
          // Try several common key variants
          String? id = ([
            'id', 'deviceId', 'address', 'mac', 'uuid'
          ].map((k) => obj[k]).firstWhere((v) => v is String && (v as String).isNotEmpty, orElse: () => null)) as String?;
          String? name = ([
            'name', 'deviceName', 'n', 'label'
          ].map((k) => obj[k]).firstWhere((v) => v is String && (v as String).isNotEmpty, orElse: () => null)) as String?;

          // If id value contains a longer payload, try to extract real id from it
          id ??= obj.values.whereType<String>().map(pickId).firstWhere((v) => v != null, orElse: () => null);

          if (id != null) return (id, name);
        }
      }

      // 2) URL / URI with query params (?id=...&name=...)
      final uri = Uri.tryParse(code);
      if (uri != null && (uri.hasScheme || code.contains('://'))) {
        // Prefer query params
        final qp = uri.queryParameters;
        String? id = qp['id'] ?? qp['deviceId'] ?? qp['mac'] ?? qp['uuid'];
        String? name = qp['name'] ?? qp['deviceName'] ?? qp['label'];
        // If id wasn't in query, try path or the whole string
        id ??= pickId(uri.path) ?? pickId(code);
        if (id != null) return (id, name);
      }

      // 3) ble: prefix (allow id or id+name in various separators)
      if (blePrefix.hasMatch(code)) {
        final rest = code.replaceFirst(blePrefix, '').trim();
        // Try common separators: ",", "|", ";"
        final parts = rest.split(RegExp(r'[|,;]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        if (parts.isEmpty) return null;

        // Find which part looks like an ID (MAC/UUID)
        String? id = parts.map(pickId).firstWhere((v) => v != null, orElse: () => null);
        String? name;

        if (id != null) {
          // The other non-id token (if any) can be name
          name = parts.firstWhere((p) => p != id && pickId(p) == null, orElse: () => '');
          if (name.isEmpty) name = null;
          return (id, name);
        } else {
          // No obvious id: treat first token as id, second as optional name
          id = parts[0];
          name = parts.length > 1 ? parts[1] : null;
          return (id, name);
        }
      }

      // 4) Raw MAC / UUID
      final m = pickId(code);
      if (m != null) return (m, null);

      return null;
    } catch (_) {
      return null; // never throw
    }
  }


// ---- Distance helpers (ScanScreen) ----
// ---- Distance helpers (ScanScreen) ----
// Physical model
  static const int _kTxAt1m = -59;       // RSSI @ 1 m (tune if you know it)
  static const double _kPathLossN = 2.0;  // 2=open space, ~2.7–3.5=indoor

// UI scaling: choose so that RSSI ≈ -70 shows ~0.12 m
// raw(-70) ≈ 3.55 m -> 0.12 / 3.55 ≈ 0.0338
  static const double _kUiScale = 0.0338;
// Optional: only cap huge values if you want
  static const double _kMaxUiMeters = 9.99;

  double? _approxDistanceMetersRaw(int rssi,
      {int txAt1m = _kTxAt1m, double n = _kPathLossN}) {
    if (rssi == 0 || rssi == 127) return null; // invalid/unavailable RSSI
    final ratio = (txAt1m - rssi) / (10 * n);
    final m = pow(10, ratio).toDouble();
    return m.isFinite ? m : null;
  }

  double? _approxDistanceMetersUi(int rssi) {
    final raw = _approxDistanceMetersRaw(rssi);
    if (raw == null) return null;
    final scaled = raw * _kUiScale;
    // IMPORTANT: no minimum clamp here
    return scaled.isFinite ? scaled.clamp(0.0, _kMaxUiMeters) : null;
  }

  String _buildDistanceSubtitle(int rssi) {
    final m = _approxDistanceMetersUi(rssi);
    if (m == null) return 'N/A';
    return 'Approx. Distance -  ${m.toStringAsFixed(2)} Mtr';
  }




  void _stopScan() {
    _scanSub?.cancel();
    _scanSub = null;
    _scanTimer?.cancel();
    _scanTimer = null;

    if (!mounted) return;
    if (_scanning) {
      setState(() => _scanning = false);
    }
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _scanSub = null;
    _scanTimer?.cancel();
    _scanTimer = null;
    _tabController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    // --- TAB 1: Ble Scan (your existing list) ---
    final listDevices = _devices.values.toList()
      ..sort((a, b) => (b.rssi).compareTo(a.rssi));

    // Connected header (unchanged logic, small tweak to call disconnect)
    Widget _connectedHeader() {
      final cs = Theme.of(context).colorScheme;
      return ValueListenableBuilder<DiscoveredDevice?>(
        valueListenable: ble.current, // requires your manager to expose `current`
        builder: (context, d, _) {
          if (d == null) return const SizedBox(height: 0); // nothing connected
          final color = _colorMap[d.id] ?? Colors.teal;
          final safeName = d.name.trim().isEmpty ? 'N/A' : d.name.trim();

          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Container(
              decoration: BoxDecoration(
                color: color.withOpacity(.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withOpacity(.30)),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: color,
                  child: const Icon(Icons.link, color: Colors.white),
                ),
                title: Text(safeName, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('Connected • ${d.id}', maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Wrap(
                  spacing: 6,
                  children: [
                    IconButton(
                      tooltip: 'Open',
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => DeviceScreen(device: d, ble: ble)),
                        );
                      },
                    ),
                    IconButton(
                      tooltip: 'Disconnect',
                      icon: const Icon(Icons.link_off),
                      onPressed: () async {
                        // Prefer a real disconnect if your manager supports it
                        try {
                          await ble.disconnect(d.id);
                        } catch (_) {}
                        // Ensure header clears if this device was current
                        if (ble.current.value?.id == d.id) {
                          ble.clearConnected();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    // --- NEW: BLE Scan tab with fixed header + scrolling list ---



    final scanTab = Column(
      children: [
        _connectedHeader(), // fixed header
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              if (allPermissionsGranted) {
                _startScan();
              }
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 4, bottom: 88), // room for FAB
              itemCount: listDevices.length,
              itemBuilder: (context, i) {
                final d = listDevices[i];
                final color = _colorMap[d.id] ?? Colors.grey;
                final subtitle = _buildDistanceSubtitle(d.rssi);
                final safeName = (d.name.trim().isEmpty) ? 'N/A' : d.name.trim();

                return DeviceTileExpandable(
                  device: d,
                  color: color,
                  rssi: d.rssi,
                  subtitleText: subtitle,
                  onConnect: () {
                    _stopScan();
                    if (!context.mounted) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => DeviceScreen(device: d, ble: ble)),
                    );
                  },
                  onRaw: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Raw Clicked $safeName")),
                    );
                  },
                  onSave: () async {
                    final fav = FavouriteDevice(id: d.id, name: d.name.isEmpty ? 'N/A' : d.name);
                    await Prefs.I.addFavourite(fav);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Saved ${fav.name}")),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );

    // --- TAB 2: Devices (unchanged) ---
      final devicesTab = listDevices.isEmpty
          ? const Center(
          child: Text('No devices discovered yet.\nRun a BLE scan to populate.',
              textAlign: TextAlign.center))
          : ListView.separated(
        itemCount: listDevices.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final d = listDevices[i];
          final color = _colorMap[d.id] ?? Colors.grey;
          return ListTile(
            leading: CircleAvatar(
                backgroundColor: color, child: const Icon(Icons.bluetooth, color: Colors.white)),
            title: Text(d.name.isEmpty ? 'N/A' : d.name),
            subtitle: Text('ID: ${d.id}\nRSSI: ${d.rssi}'),
            isThreeLine: true,
            trailing: IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => DeviceScreen(device: d, ble: ble)),
                );
              },
            ),
          );
        },
      );
    // --- TAB 3: Favourites (placeholder) ---
    // Replace this with your own favourites storage & UI.
    // --- TAB 3: Favourites ---
    final favouritesTab = FavouriteDevicesTab(ble: ble);


    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          iconTheme: const IconThemeData(color: Colors.white),
          backgroundColor: const Color(0xFF203A43),
          title: const Text('wireless', style: TextStyle(color: Colors.white)),
          actions: [
            IconButton(
              tooltip: 'Radar Scan',
              onPressed: () async {
                final selected = await Navigator.of(context).push<DiscoveredDevice>(
                  MaterialPageRoute(builder: (_) => RadarScanScreen(ble: ble)),
                );
                if (selected != null && mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => DeviceScreen(device: selected, ble: ble)),
                  );
                }
              },
              icon: const Icon(Icons.radar, color: Colors.white),
            ),
            IconButton(onPressed: _scanQrAndConnect, icon: const Icon(Icons.qr_code_2, color: Colors.white)),
            IconButton(
              tooltip: 'Device Info',
              onPressed: _showDeviceInfoSheet,
              icon: const Icon(Icons.device_unknown_outlined, color: Colors.white),
            ),
          ],
          bottom: TabBar(
            tabAlignment: TabAlignment.fill,
            controller: _tabController,
            //Label Styles
            labelColor: Colors.greenAccent,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w300),
            unselectedLabelColor: Colors.white70,

            // Ripple / hover
            splashBorderRadius: BorderRadius.circular(999),
            overlayColor: MaterialStateProperty.resolveWith((states) =>
            states.contains(MaterialState.pressed) ? Colors.white10 : null),

              // Indicator (underline) basics
              indicatorColor: Colors.greenAccent,
              indicatorWeight: 3,
              indicatorPadding: const EdgeInsets.symmetric(horizontal: 6),
            // // Change how the underline is sized relative to the tab
            // indicatorSize: TabBarIndicatorSize.tab, // .label -> tight underline under text
            //
            // // Fully custom indicator (chip/bubble, rounded bg, gradient)
            // indicator: BoxDecoration(
            //   color: Colors.white.withOpacity(0.1),
            //   borderRadius: BorderRadius.circular(12),
            //   border: Border.all(color: Colors.amber, width: 1.2),
            //   // gradient: LinearGradient(colors: [..]),
            // ),


            tabs: const [
              Tab(text: 'Ble Scan', icon: Icon(Icons.search)),
              // Tab(text: 'Devices', icon: Icon(Icons.devices_other)),
              Tab(text: 'Favourites', icon: Icon(Icons.star_border)),
            ],
          ),
        ),
        drawer: AppDrawer(
          onTapAboutDevice: () async => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AboutDeviceScreen())),
          onTapFilter: () async => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FilterScreen())),
          onTapFeedback: () async => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FeedbackScreen())),
          onTapHelp: () async => Navigator.of(context).push(MaterialPageRoute(builder: (_) => HelpScreen())),
          onTapAbout: () async => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AboutScreen())),
          onTapTutorial: () async => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TutorialScreen())),
          onTapSettings: () async => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SettingsScreen())),
          onTapSessionLogs: () async => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SessionLogsScreen())),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Ble Scan
            // Tab 1: Ble Scan -> switch between list or "off" UI
            StreamBuilder<BleStatus>(
              stream: ble.statusStream,
              initialData: BleStatus.unknown,
              builder: (context, snap) {
                final ready = snap.data == BleStatus.ready;
                return ready ? scanTab : _bluetoothOffView();
              },
            ),
            // // Tab 2: Devices
            // devicesTab,
            // Tab 3: Favourites
            favouritesTab,
          ],
        ),

        // Show the FAB only on the Ble Scan tab (index 0)
        floatingActionButton: AnimatedBuilder(

          animation: _tabController,
          builder: (context, _) {
            final onScanTab = _tabController.index == 0;
            if (!onScanTab) return const SizedBox.shrink();

            return StreamBuilder<BleStatus>(
              stream: ble.statusStream,
              initialData: BleStatus.unknown,
              builder: (context, snap) {
                final btReady = snap.data == BleStatus.ready;
                return FloatingActionButton(
                  heroTag: 'scan',
                  backgroundColor: !btReady ? Colors.grey.shade800 : const Color(0xFF203A43),
                  onPressed: (!btReady)
                      ? null // disabled when BT is off
                      : (!_scanning ? _startScan : _stopScan),
                  child: Icon(
                    btReady  ? _scanning ? Icons.stop_circle_rounded : Icons.search : Icons.bluetooth_disabled,
                    color: (!btReady)
                        ? Colors.white54
                        : (_scanning ? Colors.amber : Colors.white),
                  ),
                  tooltip: btReady ? null : 'Turn on Bluetooth to scan',
                );
              },
            );
          },
        ),

      ),
    );


  }

  Widget _bluetoothOffView() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bluetooth_disabled, size: 96, color: Colors.grey),
          const SizedBox(height: 12),
          const Text('Bluetooth is off',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Turn it on to scan for nearby devices',
              style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 16),
          // Optional: open system settings (works best if you add the `app_settings` package)
          // ElevatedButton(
          //   onPressed: () => AppSettings.openBluetoothSettings(),
          //   child: const Text('Open Bluetooth Settings'),
          // ),
        ],
      ),
    );
  }

}


