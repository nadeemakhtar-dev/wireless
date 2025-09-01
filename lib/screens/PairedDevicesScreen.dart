import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

class BleDevicesScreen extends StatefulWidget {
  const BleDevicesScreen({super.key});

  @override
  State<BleDevicesScreen> createState() => _BleDevicesScreenState();
}

class _BleDevicesScreenState extends State<BleDevicesScreen> {
  static const _ch = MethodChannel('ble/devices');

  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _ch.invokeMethod<dynamic>('fetch');
      if (!mounted) return;
      setState(() {
        _data = (res as Map).map((k, v) => MapEntry(k.toString(), v));
        _loading = false;
      });
    } on PlatformException catch (e) {
      setState(() {
        _loading = false;
        _error = 'Platform error [${e.code}]: ${e.message ?? e.details ?? 'unknown'}';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Error: $e';
      });
    }
  }

  // ----- Categorization helpers -----

  String majorClassLabel(int major) {
    switch (major) {
      case 0x0400: return 'Audio / Video';
      case 0x0100: return 'Computer';
      case 0x0200: return 'Phone';
      case 0x0500: return 'Peripheral';
      case 0x0700: return 'Wearable';
      case 0x0600: return 'Imaging';
      case 0x0800: return 'Toy';
      case 0x0900: return 'Health';
      case 0x0300: return 'Networking';
      case 0x0000: return 'Misc';
      default:     return 'Unknown';
    }
  }

  IconData majorClassIcon(int major) {
    switch (major) {
      case 0x0400: return Icons.headphones;               // Audio/Video
      case 0x0100: return Icons.computer;                 // Computer
      case 0x0200: return Icons.smartphone;               // Phone
      case 0x0500: return Icons.keyboard;                 // Peripheral
      case 0x0700: return CupertinoIcons.clock;    // Wearable
      case 0x0600: return Icons.photo_camera;             // Imaging
      case 0x0800: return Icons.toys;                     // Toy
      case 0x0900: return Icons.health_and_safety;        // Health
      case 0x0300: return Icons.router;                   // Networking
      case 0x0000: return Icons.devices_other;            // Misc
      default:     return CupertinoIcons.question_circle;
    }
  }

  Color typeColor(String type) {
    switch (type) {
      case 'le': return Colors.teal;
      case 'dual': return Colors.indigo;
      case 'classic': return Colors.deepOrange;
      default: return Colors.grey;
    }
  }

  String bondText(int bond) {
    switch (bond) {
      case 12: return 'BONDED';
      case 11: return 'BONDING';
      case 10: return 'NONE';
      default: return '$bond';
    }
  }

  Widget tag(String text, {Color? color, IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? Colors.grey).withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: (color ?? Colors.grey).withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color ?? Colors.grey),
            const SizedBox(width: 4),
          ],
          Text(text, style: TextStyle(fontSize: 12, color: color ?? Colors.grey)),
        ],
      ),
    );
  }

  Widget deviceTile(Map d) {
    final name = (d['name'] as String?)?.trim();
    final addr = d['address'] as String? ?? '—';
    final type = d['type'] as String? ?? 'unknown';
    final bond = (d['bondState'] as int?) ?? -1;
    final major = (d['majorClass'] as int?) ?? -1;

    return ListTile(
      dense: false,
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: Colors.black12,
        child: Icon(majorClassIcon(major), color: Colors.white),
      ),
      title: Text(name?.isNotEmpty == true ? name! : '(unknown)', style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(addr, style: const TextStyle(fontFamily: 'monospace')),
      trailing: Wrap(
        spacing: 8,
        children: [
          tag(type.toUpperCase(), color: typeColor(type), icon: CupertinoIcons.bluetooth),
          tag(bondText(bond)),
        ],
      ),
    );
  }

  Widget sectionCard({required String title, required Widget child, IconData? icon}) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon ?? CupertinoIcons.info, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;

    // Group paired devices by major class
    // --- above the sectionCard (right after you compute `paired`) ---

    final Map<int, List<Map<String, dynamic>>> grouped = {};
    for (final e in (data?['bonded'] as List? ?? const [])) {
      final m = Map<String, dynamic>.from(e as Map);
      final major = (m['majorClass'] as int?) ?? -1;
      grouped.putIfAbsent(major, () => []).add(m);
    }

// Sort groups by label
    final sortedGroups = grouped.entries.toList()
      ..sort((a, b) => majorClassLabel(a.key).compareTo(majorClassLabel(b.key)));


    // Recently connected & Connected GATT
    final List recent = (data?['recent'] as List?) ?? const [];
    final List connectedGatt = (data?['connectedGatt'] as List?) ?? const [];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Bluetooth Devices', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Background gradient
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
            child: RefreshIndicator(
              onRefresh: _fetch,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: Column(
                      children: [
                        if (_loading)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: LinearProgressIndicator(minHeight: 3),
                          ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          sectionCard(
                            title: 'Error',
                            icon: CupertinoIcons.exclamationmark_triangle,
                            child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                          ),
                        ],

                        // Recently connected (chips list)
                        sectionCard(
                          title: 'Recently connected',
                          icon: CupertinoIcons.clock,
                          child: recent.isEmpty
                              ? const Text('No recent devices.')
                              : Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: recent.map<Widget>((e) {
                              final m = e as Map;
                              final name = (m['name'] as String?)?.trim();
                              final type = m['type'] as String? ?? 'unknown';
                              return Chip(
                                avatar: const Icon(CupertinoIcons.bluetooth, size: 16),
                                label: Text(name?.isNotEmpty == true ? name! : (m['address'] as String? ?? 'Unknown')),
                                deleteIcon: null,
                                backgroundColor: typeColor(type).withOpacity(0.12),
                                labelStyle: TextStyle(color: typeColor(type), fontWeight: FontWeight.w600),
                              );
                            }).toList(),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Currently connected BLE (GATT)
                        sectionCard(
                          title: 'Currently connected (BLE / GATT)',
                          icon: CupertinoIcons.dot_radiowaves_left_right,
                          child: connectedGatt.isEmpty
                              ? const Text('No BLE devices currently connected.')
                              : Column(children: connectedGatt.map<Widget>((e) => deviceTile(e as Map)).toList()),
                        ),

                        const SizedBox(height: 12),

                        // Paired devices — grouped
                        // --- inside your sectionCard for "Paired devices" ---

                        sectionCard(
                          title: 'Paired devices',
                          icon: CupertinoIcons.link,
                          child: grouped.isEmpty
                              ? const Text('No paired devices found.')
                              : Column(
                            children: [
                              for (final entry in sortedGroups) Theme(
                                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  initiallyExpanded: true,
                                  leading: Icon(majorClassIcon(entry.key)),
                                  title: Text(
                                    '${majorClassLabel(entry.key)}  •  ${entry.value.length}',
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  children: [
                                    const Divider(height: 1),
                                    ...entry.value
                                        .map<Widget>((d) => deviceTile(d))
                                        .toList(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )

                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _fetch,
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh'),
      ),
    );
  }
}
