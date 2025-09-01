import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:wireless/screens/DeviceScreen.dart';

import '../../model/FavouriteModel.dart';
import '../../services/ReactiveBleManager.dart';
import '../../services/SharedPreferences.dart';

class FavouriteDevicesTab extends StatefulWidget {
  const FavouriteDevicesTab({super.key, required this.ble});
  final ReactiveBleManager ble; // your wrapper type used in ScanScreen

  @override
  State<FavouriteDevicesTab> createState() => _FavouriteDevicesTabState();
}

class _FavouriteDevicesTabState extends State<FavouriteDevicesTab> {
  late Future<List<FavouriteDevice>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<FavouriteDevice>> _load() async {
    // If Prefs.I.init() is already called in main(), this is instant.
    return Prefs.I.getFavourites();
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
  }

  Future<void> _remove(FavouriteDevice d) async {
    await Prefs.I.removeFavourite(d.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Removed ${d.name.isEmpty ? d.id : d.name}')),
    );
    _refresh();
  }

  void _connect(FavouriteDevice d) {
    // Create a placeholder DiscoveredDevice (same pattern as your QR flow)
    final placeholder = DiscoveredDevice(
      id: d.id,
      name: d.name.isEmpty ? d.id : d.name,
      rssi: 0,
      serviceData: const {},
      manufacturerData: Uint8List(0),
      serviceUuids: const [],
    );

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DeviceScreen(device: placeholder, ble: widget.ble)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return FutureBuilder<List<FavouriteDevice>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data ?? const <FavouriteDevice>[];

        if (items.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              children: const [
                SizedBox(height: 120),
                Center(
                  child: Text(
                    'No favourites yet.\nTap “Save” on a device to add it here.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final d = items[i];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: cs.outlineVariant.withOpacity(.35)),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: cs.primary.withOpacity(.12),
                    child: const Icon(Icons.bluetooth, color: Colors.blue),
                  ),
                  title: Text(
                    d.name.isEmpty ? 'N/A' : d.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    d.id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      _MiniActionButton(
                        icon: Icons.link_rounded,
                        label: 'Connect',
                        onTap: () => _connect(d),
                      ),
                      _MiniActionButton(
                        icon: Icons.delete_outline_rounded,
                        label: 'Remove',
                        onTap: () => _remove(d),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  const _MiniActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primary.withOpacity(.10),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
