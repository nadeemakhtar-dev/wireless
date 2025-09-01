import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:wireless/BLEAdvertiser/AdvertiserScreen.dart';
import 'package:wireless/screens/TestingScreens/AdvertisementScreen.dart';

/// Elegant, modern, and **responsive** Coming Soon page for
/// Wireless → Advertisement Module.

/// ✅ Fixes common RenderFlex overflows by:
///   - Wrapping content in SingleChildScrollView
///   - Constraining width and using Wrap/Grid for horizontal groups
///   - Using bottom sheets that can scroll
/// ✅ Looks great on phones, tablets, and desktop widths.
/// ✅ Primary CTA: "Test Beta v0.1.2" → navigates to '/advertise-beta'
/// ✅ Secondary: Module details sheet

/// Drop into your app and add a route for '/advertise-beta'.


class AdvertisementComingSoonPage extends StatelessWidget {
  const AdvertisementComingSoonPage({super.key});

  static const String betaVersion = "0.1.2";

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDark = theme.brightness == Brightness.dark;
          return Stack(
            children: [
              _AnimatedBackdrop(isDark: isDark),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 920),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 12),
                          _HeaderBadges(version: betaVersion),
                          const SizedBox(height: 28),
                          const _HeroLockup(),
                          const SizedBox(height: 28),
                          _Ctas(version: betaVersion),
                          const SizedBox(height: 28),
                          _FeatureGrid(maxWidth: constraints.maxWidth),
                          const SizedBox(height: 24),
                          const _Footnote(),
                          const SizedBox(height: 24),
                        ],
                      ),
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

/// ————————————————————————————————————————————————————————————————
/// VISUALS
/// ————————————————————————————————————————————————————————————————

class _AnimatedBackdrop extends StatefulWidget {
  const _AnimatedBackdrop({required this.isDark});
  final bool isDark;

  @override
  State<_AnimatedBackdrop> createState() => _AnimatedBackdropState();
}

class _AnimatedBackdropState extends State<_AnimatedBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 10))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.isDark;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = CurvedAnimation(parent: _c, curve: Curves.easeInOut).value;
          final base = dark
              ? [const Color(0xFF0F172A), const Color(0xFF1F2937)]
              : [const Color(0xFFEFF6FF), const Color(0xFFE0E7FF)];
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(base.first, Colors.purple.shade200, dark ? 0.06 : 0.18)!,
                  Color.lerp(base.last, Colors.blue.shade200, dark ? 0.06 : 0.18)!,
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 80 + 20 * math.sin(t * math.pi * 2),
                  left: -60,
                  child: _blob(200, dark ? Colors.blueGrey.shade700 : Colors.blue.shade100),
                ),
                Positioned(
                  bottom: 60 + 24 * math.cos(t * math.pi * 2),
                  right: -40,
                  child: _blob(160, dark ? Colors.deepPurple.shade700 : Colors.purple.shade100),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _blob(double size, Color color) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.18),
            blurRadius: 60,
            spreadRadius: 10,
          ),
        ],
      ),
    ),
  );
}

class _HeaderBadges extends StatelessWidget {
  const _HeaderBadges({required this.version});
  final String version;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.7),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: onSurface.withOpacity(0.08)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.bluetooth, size: 16),
            const SizedBox(width: 6),
            Text(
              "Wireless • Advertisement Module",
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ]),
        ),
        Chip(
          avatar: const Icon(Icons.science, size: 16),
          label: Text("Beta $version"),
          side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.4)),
          backgroundColor: theme.colorScheme.primary.withOpacity(0.10),
        ),
      ],
    );
  }
}

class _HeroLockup extends StatelessWidget {
  const _HeroLockup();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // Gradient headline with subtle sheen
        ShaderMask(
          shaderCallback: (rect) {
            return LinearGradient(
              colors: isDark
                  ? [Colors.white, Colors.white70, Colors.white]
                  : [Colors.black87, Colors.black54, Colors.black87],
              stops: const [0.2, 0.5, 0.8],
            ).createShader(rect);
          },
          blendMode: BlendMode.srcIn,
          child: Text(
            "Coming Soon..",
            textAlign: TextAlign.center,
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "We’re polishing an in‑app BLE Advertiser for fast discovery and simple controls.",
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.75),
          ),
        ),
        const SizedBox(height: 24),
        // Decorative hero icon
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.primary.withOpacity(0.10),
            border: Border.all(color: theme.colorScheme.primary.withOpacity(0.25)),
          ),
          child: Icon(Icons.broadcast_on_home, size: 56, color: theme.colorScheme.primary),
        ),
      ],
    );
  }
}

class _Ctas extends StatelessWidget {
  const _Ctas({required this.version});
  final String version;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          FilledButton.icon(
            icon: const Icon(Icons.rocket_launch),
            label: Text("Test Beta v$version"),
            onPressed: () async {
              final ok = await _showBetaGuardDialog(context, version);
              if (ok && context.mounted) {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => AdvertiseScreen()));
              }
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 1,
            ),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.description_outlined),
            label: const Text("Module Details"),
            onPressed: () => _showDetailsSheet(context),
          ),
        ],
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.maxWidth});
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final features = const [
      (
      Icons.campaign_outlined,
      "BLE Advertiser",
      "Broadcast Service UUID & optional Local Name",
      ),
      (
      Icons.speed,
      "Low‑latency",
      "Short intervals during active testing for quick discovery",
      ),
      (
      Icons.usb_rounded,
      "Connectable (optional)",
      "Enable only when a GATT server is available",
      ),
      (
      Icons.security_outlined,
      "Permission‑aware",
      "Guides Android 12+ & iOS Bluetooth prompts",
      ),
      (
      Icons.analytics_outlined,
      "Status & errors",
      "Clear surfacing of start/stop and failures",
      ),
      (
      Icons.devices_other,
      "Multi‑device",
      "Looks great from small phones to tablets",
      ),
    ];

    int cols;
    if (maxWidth >= 980) {
      cols = 3;
    } else if (maxWidth >= 640) {
      cols = 2;
    } else {
      cols = 1;
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: cols == 1 ? 3.2 : 2.8,
      ),
      itemCount: features.length,
      itemBuilder: (context, i) {
        final f = features[i];
        return _FeatureCard(icon: f.$1, title: f.$2, subtitle: f.$3);
      },
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface.withOpacity(0.85),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 24, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.75),
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

class _Footnote extends StatelessWidget {
  const _Footnote();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      "Beta builds may be unstable and limited on certain devices (e.g., iOS background constraints).",
      textAlign: TextAlign.center,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurface.withOpacity(0.7),
      ),
    );
  }
}

/// ————————————————————————————————————————————————————————————————
/// DIALOGS & SHEETS (scroll‑safe)
/// ————————————————————————————————————————————————————————————————

Future<bool> _showBetaGuardDialog(BuildContext context, String version) async {
  final theme = Theme.of(context);
  return await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      title: Row(children: [
        const Icon(Icons.warning_amber_rounded),
        const SizedBox(width: 8),
        Text("Beta $version"),
      ]),
      content: const Text(
        "You’re about to open the Advertisement Module (Beta). "
            "Features may change and some devices may require extra permissions. "
            "Proceed only if you’re okay with potential bugs.",
      ),
      actions: [
        TextButton(
          child: const Text("Cancel"),
          onPressed: () => Navigator.pop(context, false),
        ),
        FilledButton(
          child: const Text("I Understand, Continue"),
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    ),
  ) ??
      false;
}

void _showDetailsSheet(BuildContext context) {
  final theme = Theme.of(context);
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: theme.colorScheme.surface,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.35,
      minChildSize: 0.25,
      maxChildSize: 0.8,
      expand: false,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: const [
          ListTile(
            leading: Icon(Icons.campaign_outlined),
            title: Text("Broadcast & Discover"),
            subtitle: Text("Advertise Service UUID & Local Name for fast scans."),
          ),
          ListTile(
            leading: Icon(Icons.speed),
            title: Text("Low‑latency mode"),
            subtitle: Text("Optimized advertise intervals during active testing."),
          ),
          ListTile(
            leading: Icon(Icons.phonelink_setup),
            title: Text("Permissions"),
            subtitle: Text("Android 12+: BLUETOOTH_SCAN/ADVERTISE/CONNECT • iOS: Bluetooth usage."),
          ),
          SizedBox(height: 8),
        ],
      ),
    ),
  );
}
