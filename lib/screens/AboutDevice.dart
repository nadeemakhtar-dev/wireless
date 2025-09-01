import 'dart:io';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class AboutDeviceScreen extends StatefulWidget {
  const AboutDeviceScreen({super.key});

  @override
  State<AboutDeviceScreen> createState() => _AboutDeviceScreenState();
}

class _AboutDeviceScreenState extends State<AboutDeviceScreen> {
  late Future<_AboutData> _load;

  @override
  void initState() {
    super.initState();
    _load = _gather();
  }

  Future<_AboutData> _gather() async {
    final deviceInfo = DeviceInfoPlugin();
    final pkg = await PackageInfo.fromPlatform();

    String os = '', osVersion = '', model = '', brand = '', device = '', sdk = '', manufacturer = '';
    String locale = '', screen = '';

    // Basic display info
    final mq = WidgetsBinding.instance.platformDispatcher.views.first.physicalSize /
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    screen = '${mq.width.toStringAsFixed(0)} × ${mq.height.toStringAsFixed(0)}';

    // Locale (best-effort)
    final locales = WidgetsBinding.instance.platformDispatcher.locales;
    if (locales.isNotEmpty) {
      final l = locales.first;
      locale = '${l.languageCode}_${l.countryCode ?? ""}';
    }

    if (Platform.isAndroid) {
      final a = await deviceInfo.androidInfo;
      os = 'Android';
      osVersion = '${a.version.release} (SDK ${a.version.sdkInt})';
      sdk = '${a.version.sdkInt}';
      model = a.model ?? '';
      brand = a.brand ?? '';
      device = a.device ?? '';
      manufacturer = a.manufacturer ?? '';
    } else if (Platform.isIOS) {
      final i = await deviceInfo.iosInfo;
      os = 'iOS';
      osVersion = i.systemVersion ?? '';
      model = i.utsname.machine ?? '';
      brand = 'Apple';
      device = i.name ?? '';
      manufacturer = 'Apple';
    } else {
      os = Platform.operatingSystem;
      osVersion = Platform.operatingSystemVersion;
    }


    return _AboutData(
      os: os,
      osVersion: osVersion,
      model: model,
      brand: brand,
      device: device,
      manufacturer: manufacturer,
      sdk: sdk,
      locale: locale,
      screen: screen,
      appName: pkg.appName,
      version: '${pkg.version}+${pkg.buildNumber}',
      packageName: pkg.packageName,
      paired: [],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(
          color: Colors.white
        ),
        title: const Text('About This Device',style: TextStyle(color: Colors.white),),
        backgroundColor: Color(0xFF2C5364),
      ),
      body: FutureBuilder<_AboutData>(
        future: _load,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Failed to load device info:\n${snap.error}'),
              ),
            );
          }
          final data = snap.data!;

          return CustomScrollView(
            slivers: [
              // Hero header
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF203A43), Color(0xFF2C5364)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(.12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Icon(Icons.phone_iphone_rounded, color: Colors.white, size: 30),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${data.brand} ${data.model}',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text('${data.os} • ${data.osVersion}',
                                style: TextStyle(color: Colors.white.withOpacity(.9))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Device Info Card
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _SectionCard(
                    title: 'Device Information',
                    child: Column(
                      children: [
                        _InfoRow(icon: Icons.badge_rounded, label: 'Manufacturer', value: data.manufacturer.isEmpty ? '—' : data.manufacturer),
                        _InfoRow(icon: Icons.devices_other_rounded, label: 'Model', value: data.model.isEmpty ? '—' : data.model),
                        _InfoRow(icon: Icons.category_rounded, label: 'Brand', value: data.brand.isEmpty ? '—' : data.brand),
                        _InfoRow(icon: Icons.memory_rounded, label: 'Device', value: data.device.isEmpty ? '—' : data.device),
                        _InfoRow(icon: Icons.language_rounded, label: 'Locale', value: data.locale.isEmpty ? '—' : data.locale),
                        _InfoRow(icon: Icons.aspect_ratio_rounded, label: 'Screen', value: data.screen.isEmpty ? '—' : data.screen),
                        if (data.sdk.isNotEmpty)
                          _InfoRow(icon: Icons.settings_ethernet_rounded, label: 'SDK', value: data.sdk),
                      ],
                    ),
                  ),
                ),
              ),

              // Paired Bluetooth Devices
              // SliverPadding(
              //   padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              //   sliver: SliverToBoxAdapter(
              //     child: _SectionCard(
              //       title: 'Paired Bluetooth Devices',
              //       subtitle: Platform.isIOS
              //           ? 'iOS does not expose a public list of paired BLE devices to apps.'
              //           : null,
              //       child: Builder(
              //         builder: (context) {
              //           if (data.paired.isEmpty) {
              //             return Padding(
              //               padding: const EdgeInsets.symmetric(vertical: 8),
              //               child: Text(
              //                 Platform.isAndroid
              //                     ? 'No bonded devices found or Bluetooth permission denied/adapter off.'
              //                     : 'Not available on this platform.',
              //                 style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              //               ),
              //             );
              //           }
              //           return Column(
              //             children: data.paired.map((p) {
              //               return Card(
              //                 elevation: 0,
              //                 margin: const EdgeInsets.symmetric(vertical: 6),
              //                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              //                 child: ListTile(
              //                   leading: CircleAvatar(
              //                     backgroundColor: cs.primary.withOpacity(.12),
              //                     child: Icon(Icons.bluetooth_rounded, color: cs.primary),
              //                   ),
              //                   title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              //                   subtitle: Text('${p.address}  •  ${p.type}'),
              //                   trailing: _BondBadge(bonded: p.isBonded, connected: p.isConnected),
              //                 ),
              //               );
              //             }).toList(),
              //           );
              //         },
              //       ),
              //     ),
              //   ),
              // ),

              // App Footer Card
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                sliver: SliverToBoxAdapter(
                  child: _SectionCard(
                    title: 'Application',
                    child: Column(
                      children: [
                        _InfoRow(icon: Icons.apps_rounded, label: 'Name', value: data.appName),
                        _InfoRow(icon: Icons.tag_rounded, label: 'Version', value: data.version),
                        _InfoRow(icon: Icons.insert_drive_file_rounded, label: 'Package', value: data.packageName),
                        const Divider(height: 24),
                        Center(
                          child: Text(
                            'Wireless • © Aerofit Inc.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Data container ─────────────────────────────────────────────────────────────

class _AboutData {
  _AboutData({
    required this.os,
    required this.osVersion,
    required this.model,
    required this.brand,
    required this.device,
    required this.manufacturer,
    required this.sdk,
    required this.locale,
    required this.screen,
    required this.appName,
    required this.version,
    required this.packageName,
    required this.paired,
  });

  final String os, osVersion, model, brand, device, manufacturer, sdk, locale, screen;
  final String appName, version, packageName;
  final List<_Paired> paired;
}

class _Paired {
  _Paired({
    required this.name,
    required this.address,
    required this.isConnected,
    required this.isBonded,
    required this.type,
  });

  final String name;
  final String address;
  final bool isConnected;
  final bool isBonded;
  final String type;
}

// ── UI widgets ────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, this.subtitle, required this.child});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      surfaceTintColor: cs.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.info_outline_rounded, color: cs.primary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ]),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: TextStyle(color: cs.onSurfaceVariant)),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: cs.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(value.isEmpty ? '—' : value, style: TextStyle(color: cs.onSurfaceVariant)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _BondBadge extends StatelessWidget {
  const _BondBadge({required this.bonded, required this.connected});
  final bool bonded;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = connected ? Colors.green : (bonded ? Colors.blue : Colors.grey);
    final label = connected ? 'Connected' : (bonded ? 'Bonded' : 'Unbonded');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.45)),
      ),
      child: Text(label, style: TextStyle(color: color.shade700, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }
}

extension on Color {
  /// `shade700()` that works for non-Material colors by darkening a bit
  Color shade700() {
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
  }
}
