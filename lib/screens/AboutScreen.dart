import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // add url_launcher to pubspec
// Optionally: package_info_plus for dynamic version/build info

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  // ── Helpers ──────────────────────────────────────────────────────────────────
  static Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // ignore: use_build_context_synchronously
      debugPrint('Could not open $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        elevation: 0,
        iconTheme: IconThemeData(
          color: Colors.white,
        ),
        backgroundColor: Color(0xFF2C5364),
        title: const Text('About Wireless',style: TextStyle(color: Colors.white),),
      ),
      body: CustomScrollView(
        slivers: [
          // ── Hero Header ───────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [ Color(0xFF203A43), Color(0xFF2C5364)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 96, height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(.12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Center(
                      child: Icon(Icons.bluetooth_searching_rounded,
                          color: Colors.white, size: 54),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Wireless',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Aerofit Inc.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(.9),
                      fontSize: 14,
                      letterSpacing: .3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: const [
                      _StatChip(icon: Icons.bluetooth, label: 'BLE'),
                      _StatChip(icon: Icons.radar, label: 'Scanner'),
                      _StatChip(icon: Icons.security_rounded, label: 'Secure'),
                      _StatChip(icon: Icons.speed, label: 'Fast'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Company ───────────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(
              child: _SectionCard(
                title: 'About Aerofit Inc.',
                subtitle: 'Smarter, wirelessly.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Aerofit Inc. builds reliable wireless experiences for health, sports, and IoT. '
                          'We focus on secure BLE connectivity, robust device tooling, and delightful user interfaces.',
                    ),
                    SizedBox(height: 10),
                    _Bullet(text: 'BLE device discovery, pairing, and diagnostics'),
                    _Bullet(text: 'Low-latency telemetry & firmware-friendly tooling'),
                    _Bullet(text: 'Human-centered design for technicians & end users'),
                  ],
                ),
              ),
            ),
          ),

          // ── People ────────────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(
              child: _SectionCard(
                title: 'Head Developer & Designer',
                subtitle: 'Craft, performance, and detail.',
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Color(0xFF2C5364),
                      child: const Text(
                        'NA',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Nadeem Akhtar',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(
                            'Designer,Developer & Research in wireless devices..',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8, runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _open('mailto:hello@aerofit.example'),
                                icon: const Icon(Icons.email_outlined, size: 18),
                                label: const Text('Email'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _open('https://www.linkedin.com/'),
                                icon: const Icon(Icons.link, size: 18),
                                label: const Text('LinkedIn'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _open('https://github.com/'),
                                icon: const Icon(Icons.code, size: 18),
                                label: const Text('GitHub'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _open('https://github.com/'),
                                icon: const Icon(Icons.post_add, size: 18),
                                label: const Text('Linkedin'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Product details / features ────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(
              child: _SectionCard(
                title: 'What Wireless does',
                subtitle: 'Built for technicians, crafted for humans.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _FeatureTile(
                      icon: Icons.search_rounded,
                      title: 'Scan & Filter',
                      body: 'Discover nearby BLE devices with name filtering, auto-stop, and radar view.',
                    ),
                    _FeatureTile(
                      icon: Icons.link_rounded,
                      title: 'Connect & Pair',
                      body: 'Stable connect flow with bond status (Android), RSSI hints, and graceful error handling.',
                    ),
                    _FeatureTile(
                      icon: Icons.memory_rounded,
                      title: 'Services & Characteristics',
                      body: 'Browse services, read/notify, and write data (Hex / String / Bytes CSV) with smart dialogs.',
                    ),
                    _FeatureTile(
                      icon: Icons.qr_code_2_rounded,
                      title: 'QR Quick Connect',
                      body: 'Scan QR payloads (MAC/UUID) and jump straight to the device.',
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Contact & Legal ───────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(
              child: _SectionCard(
                title: 'Contact & Info',
                child: Column(
                  children: [
                    _InfoRow(
                      icon: Icons.alternate_email_rounded,
                      label: 'Email',
                      value: 'support@aerofit.example',
                      onTap: () => _open('mailto:support@aerofit.example'),
                    ),
                    _InfoRow(
                      icon: Icons.public_rounded,
                      label: 'Website',
                      value: 'www.aerofit.example',
                      onTap: () => _open('https://www.aerofit.example'),
                    ),
                    _InfoRow(
                      icon: Icons.policy_rounded,
                      label: 'Privacy',
                      value: 'View privacy policy',
                      onTap: () => _open('https://www.aerofit.example/privacy'),
                    ),
                    const Divider(height: 20),
                    _InfoRow(
                      icon: Icons.tag_rounded,
                      label: 'App Version',
                      value: 'v1.0.0', // optionally fetch via package_info_plus
                    ),
                    _InfoRow(
                      icon: Icons.balance_rounded,
                      label: 'License',
                      value: 'All rights reserved · © Aerofit Technologies Inc.',
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Footer spacing ────────────────────────────────────────────────────
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

// ── UI Pieces ─────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    this.subtitle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surface,
      surfaceTintColor: cs.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.blur_circular_rounded, color: cs.primary),
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

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.12),
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: Colors.white),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_circle_rounded, size: 16, color: Colors.teal),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(.35),
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(body),
            ]),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value, this.onTap});
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final row = Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(color: cs.onSurfaceVariant)),
          ]),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: onTap == null ? row : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: row),
    );
  }
}
