import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

// Your scanner class:
import '../scanner/BeaconScanner.dart'; // UniversalIBeaconScanner, IBeacon

class IBeaconScannerScreen extends StatefulWidget {
  const IBeaconScannerScreen({Key? key}) : super(key: key);

  @override
  State<IBeaconScannerScreen> createState() => _IBeaconScannerScreenState();
}

class _IBeaconScannerScreenState extends State<IBeaconScannerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _scanner = UniversalIBeaconScanner();

  StreamSubscription<IBeacon>? _sub;
  final Map<String, _SeenBeacon> _seen = {};
  final TextEditingController _uuidFilterCtrl = TextEditingController();

  bool _scanning = false;
  Timer? _gcTimer;

  @override
  void initState() {
    super.initState();
    // _ensurePermissions();
    _gcTimer = Timer.periodic(const Duration(seconds: 5), (_) => _prune());
    _uuidFilterCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _gcTimer?.cancel();
    _uuidFilterCtrl.dispose();
    _stop();
    _tabs.dispose();
    super.dispose();
  }

  // Future<void> _ensurePermissions() async {
  //   await [
  //     Permission.bluetoothScan,
  //     Permission.bluetoothConnect,
  //     Permission.locationWhenInUse, // needed on Android 10–11
  //   ].request();
  // }

  String _keyFor(IBeacon b) => '${b.uuid}:${b.major}:${b.minor}';

  Future<void> _start() async {
    if (_scanning) return;
    setState(() => _scanning = true);

    _sub = _scanner.scan().listen((b) {
      final filter = _uuidFilterCtrl.text.trim();
      if (filter.isNotEmpty && b.uuid.toLowerCase() != filter.toLowerCase()) {
        return;
      }
      _seen[_keyFor(b)] = _SeenBeacon(b, DateTime.now());
      if (mounted) setState(() {});
    }, onError: (e, st) {
      setState(() => _scanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan error: $e')),
      );
    }, onDone: () {
      if (mounted) setState(() => _scanning = false);
    });

    // ⏱️ stop automatically after 10 seconds
    Timer(const Duration(seconds: 10), () {
      if (mounted && _scanning) {
        _stop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scan stopped after 10 seconds')),
        );
      }
    });
  }


  Future<void> _stop() async {
    await _sub?.cancel();
    _scanner.stop();
    if (mounted) setState(() => _scanning = false);
  }

  void _prune() {
    final cutoff = DateTime.now().subtract(const Duration(seconds: 10));
    _seen.removeWhere((_, sb) => sb.lastSeen.isBefore(cutoff));
    if (mounted) setState(() {});
  }

  void _clear() {
    _seen.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final beacons = _seen.values.map((e) => e.beacon).toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));

    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(
          color: Colors.white
        ),
        backgroundColor: Color(0xFF203A43),
        title: const Text('iBeacon Scanner',style: TextStyle(color: Colors.white),),
        bottom: TabBar(
          controller: _tabs,
          unselectedLabelColor: Colors.white,
          labelColor: Colors.amber,
          indicatorColor: Colors.amber,
          tabs: const [
            Tab(


                icon: Icon(Icons.wifi_tethering,color: Colors.white,), text: 'Scan'),
            Tab(icon: Icon(Icons.info_outline,color: Colors.white,), text: 'About'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Clear list',
            icon: const Icon(Icons.clear_all,color: Colors.white,),
            onPressed: beacons.isEmpty ? null : _clear,
          ),
          const SizedBox(width: 4),
        ],
      ),
      // floatingActionButton: _tabs.index == 0
      //     ? FloatingActionButton.extended(
      //   onPressed: _scanning ? _stop : _start,
      //   icon: Icon(_scanning ? Icons.stop : Icons.play_arrow),
      //   label: Text(_scanning ? 'Stop' : 'Start Scan'),
      // )
      //     : null,
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildScanTab(context, beacons),
          const _AboutTab(),
        ],
      ),
    );
  }

  // -------------------- Scan tab --------------------

  Widget _buildScanTab(BuildContext context, List<IBeacon> beacons) {
    return Column(
      children: [
        _HeaderCard(
          scanning: _scanning,
          onStart: _start,
          onStop: _stop,
        ),
        _FilterBar(controller: _uuidFilterCtrl),
        const Divider(height: 1),
        Expanded(
          child: beacons.isEmpty ? _EmptyExplainer(onStart: _start) : _BeaconList(beacons: beacons),
        ),
        _FooterBar(scanning: _scanning, count: beacons.length),
      ],
    );
  }
}

// -------------------- Widgets --------------------

class _HeaderCard extends StatelessWidget {
  final bool scanning;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const _HeaderCard({
    Key? key,
    required this.scanning,
    required this.onStart,
    required this.onStop,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.bluetooth_searching, color: scheme.onPrimaryContainer, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              scanning ? 'Scanning for iBeacons…' : 'Ready to scan for iBeacons',
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: scanning ? onStop : onStart,
            icon: Icon(scanning ? Icons.stop : Icons.play_arrow),
            label: Text(scanning ? 'Stop' : 'Scan'),
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: scheme.onPrimaryContainer,
              foregroundColor: scheme.primaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final TextEditingController controller;
  const _FilterBar({Key? key, required this.controller}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.filter_alt_outlined),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Clear filter',
            onPressed: () {
              controller.clear();
              FocusScope.of(context).unfocus();
            },
          ),
          labelText: 'Filter by UUID (optional)',
          hintText: 'e.g. E2C56DB5-DFFB-48D2-B060-D0F5A71096E0',
          filled: true,
          fillColor: scheme.surfaceVariant.withOpacity(0.5),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.search,
      ),
    );
  }
}

class _EmptyExplainer extends StatelessWidget {
  final Future<void> Function() onStart;
  const _EmptyExplainer({Key? key, required this.onStart}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center, // centers when content < screen
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.sensors, size: 64, color: scheme.outline),
                  const SizedBox(height: 12),
                  Text('No beacons yet', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Tap “Start Scan” to discover nearby iBeacon transmitters.\n'
                        'Tip: Ensure Bluetooth is ON. On some Android phones, Location Services must also be ON.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: const [
                      _HintChip(icon: Icons.wifi_tethering, text: 'iBeacon = BLE advertiser'),
                      _HintChip(icon: Icons.grid_view, text: 'UUID + Major + Minor'),
                      _HintChip(icon: Icons.route, text: 'Proximity via RSSI'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Scan'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HintChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HintChip({Key? key, required this.icon, required this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _BeaconList extends StatelessWidget {
  final List<IBeacon> beacons;
  const _BeaconList({Key? key, required this.beacons}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: beacons.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final b = beacons[i];
          final distance = _estimateDistance(b.txPower, b.rssi);
          final prox = _proximity(distance);
          return _BeaconTile(
            beacon: b,
            distance: distance,
            proximity: prox.$1,
            proximityColor: prox.$2,
          );
        },
      ),
    );
  }

  // Distance estimate from RSSI + Tx power (rough!)
  static double? _estimateDistance(int txPower, int rssi) {
    if (rssi == 0 || txPower == 0) return null;
    // Path-loss exponent n ≈ 2.0 (free space). Tweak 2–4 for indoor environments.
    final ratio = (txPower - rssi) / (10.0 * 2.0);
    return math.pow(10, ratio).toDouble();
  }

  // Map distance to friendly proximity label + color
  (String, Color) _proximity(double? distance) {
    final theme = Colors.teal; // base color for proximity badges
    if (distance == null) return ('Unknown', Colors.grey);
    if (distance < 0.5) return ('Immediate', theme.shade700);
    if (distance < 3.0) return ('Near', theme.shade500);
    return ('Far', theme.shade300);
  }
}

class _BeaconTile extends StatelessWidget {
  final IBeacon beacon;
  final double? distance;
  final String proximity;
  final Color proximityColor;

  const _BeaconTile({
    Key? key,
    required this.beacon,
    required this.distance,
    required this.proximity,
    required this.proximityColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      title: SelectableText(
        beacon.uuid,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _InfoPill(icon: Icons.numbers, label: 'Major', value: '${beacon.major}'),
                _InfoPill(icon: Icons.tag, label: 'Minor', value: '${beacon.minor}'),
                _InfoPill(icon: Icons.bolt, label: 'Tx', value: '${beacon.txPower} dBm'),
                _InfoPill(icon: Icons.network_wifi, label: 'RSSI', value: '${beacon.rssi} dBm'),
                _ProximityPill(text: proximity, color: proximityColor),
              ],
            ),
            const SizedBox(height: 8),
            _SignalBar(rssi: beacon.rssi),
          ],
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            distance != null ? '${distance!.toStringAsFixed(2)} m' : '—',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (beacon.name.isNotEmpty)
            Text(beacon.name, style: const TextStyle(fontSize: 12)),
          IconButton(
            tooltip: 'Copy UUID',
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () => Clipboard.setData(ClipboardData(text: beacon.uuid)).then((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('UUID copied')),
              );
            }),
          ),
        ],
      ),
      dense: false,
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoPill({Key? key, required this.icon, required this.label, required this.value})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text('$label: $value', style: TextStyle(color: color)),
        ],
      ),
    );
  }
}

class _ProximityPill extends StatelessWidget {
  final String text;
  final Color color;
  const _ProximityPill({Key? key, required this.text, required this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final onColor = Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: TextStyle(color: onColor, fontWeight: FontWeight.w600)),
    );
  }
}

class _SignalBar extends StatelessWidget {
  final int rssi;
  const _SignalBar({Key? key, required this.rssi}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Map RSSI (~-100..-30) to 0..1
    final norm = ((rssi + 100) / 70).clamp(0.0, 1.0);
    return SizedBox(
      height: 8,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: norm,
          backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
        ),
      ),
    );
  }
}

class _FooterBar extends StatelessWidget {
  final bool scanning;
  final int count;
  const _FooterBar({Key? key, required this.scanning, required this.count}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final txt = scanning
        ? 'Scanning… $count beacon${count == 1 ? '' : 's'} found'
        : '$count beacon${count == 1 ? '' : 's'} total';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Text(
        txt,
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

// Track last time we saw a beacon
class _SeenBeacon {
  final IBeacon beacon;
  final DateTime lastSeen;
  _SeenBeacon(this.beacon, this.lastSeen);
}

// -------------------- About tab --------------------

class _AboutTab extends StatelessWidget {
  const _AboutTab();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _AboutCard(
          icon: Icons.lightbulb_outline,
          title: 'What is an iBeacon?',
          body:
          'An iBeacon is a tiny Bluetooth Low Energy (BLE) transmitter. It repeatedly broadcasts a small packet that nearby phones can hear. '
              'The packet includes a UUID (who it belongs to), plus a Major & Minor number (which beacon it is). Apps don’t usually connect to a beacon — they simply “hear” it.',
        ),
        _AboutCard(
          icon: Icons.hub_outlined,
          title: 'How this app detects beacons',
          body:
          'Your phone listens for BLE “advertising” packets. This app looks for the iBeacon signature in the Manufacturer Data and then shows the UUID/Major/Minor, signal strength (RSSI) and a rough distance estimate.',
        ),
        _AboutCard(
          icon: Icons.place_outlined,
          title: 'Where iBeacons are used',
          body:
          'Indoor wayfinding (museums, malls), proximity prompts (exhibits, offers), asset tracking, smart home triggers, and more.',
        ),
        _AboutSteps(
          steps: const [
            ('Enable Bluetooth', 'Make sure Bluetooth is ON. On some Android devices, Location Services must also be ON.'),
            ('Tap “Start Scan”', 'Stand near a beacon to see it appear in the list.'),
            ('Filter (optional)', 'If you know the UUID, paste it to see only those beacons.'),
            ('Interpret results', 'Stronger RSSI and “Immediate” proximity mean the beacon is close. Distance is only an estimate.'),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: scheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.shield_moon_outlined, color: scheme.onSecondaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Privacy note: scanning is passive — your phone just listens. This app does not connect to beacons or send data to them.',
                    style: TextStyle(color: scheme.onSecondaryContainer),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AboutCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _AboutCard({Key? key, required this.icon, required this.title, required this.body})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
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

class _AboutSteps extends StatelessWidget {
  final List<(String, String)> steps;
  const _AboutSteps({Key? key, required this.steps}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Getting started', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...steps.asMap().entries.map((e) {
              final idx = e.key + 1;
              final (title, body) = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: scheme.primary,
                      child: Text('$idx', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(body, style: TextStyle(color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
