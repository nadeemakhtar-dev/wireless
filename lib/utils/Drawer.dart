// lib/widgets/app_drawer.dart
import 'package:flutter/material.dart';
// import your ElegantTile if you use it
import '../utils/ElegantTile.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    this.onTapBleScan,
    this.onTapFilter,
    this.onTapDevices,
    this.onTapAboutDevice,
    this.onTapFeedback,
    this.onTapHelp,
    this.onTapTutorial,
    this.onTapSessionLogs,
    this.onTapSettings,
    this.onTapAbout,
    this.version = 'v1.0.0',
    this.width = 230,
  });

  // Callbacks (optional)
  final VoidCallback? onTapBleScan;
  final VoidCallback? onTapFilter;
  final VoidCallback? onTapDevices;
  final VoidCallback? onTapAboutDevice;
  final VoidCallback? onTapFeedback;
  final VoidCallback? onTapHelp;
  final VoidCallback? onTapTutorial;
  final VoidCallback? onTapSessionLogs;
  final VoidCallback? onTapSettings;
  final VoidCallback? onTapAbout;

  final String version;
  final double width;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      width: width,
      child: Drawer(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        clipBehavior: Clip.hardEdge,
        child: Column(
          children: [
            // Header
            SafeArea(
              bottom: false,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF263238), Color(0xFF37474F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white24,
                      child: const Icon(Icons.bluetooth_connected_sharp,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Aerofit Inc.",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 25,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .3,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Smarter, wirelessly.",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const SizedBox(height: 8),
                  // Section: Main
                  const _SectionLabel('Main'),
                  ElegantTile(
                    icon: Icons.manage_search_outlined,
                    label: "Scanner",
                    onTap: onTapBleScan ?? () => Navigator.pop(context),
                  ),
                  ElegantTile(
                    icon: Icons.devices,
                    label: "Filter Params",
                    subtitle: "Filtered Scan..",
                    onTap: onTapFilter ?? () => Navigator.pop(context),
                  ),
                  ElegantTile(
                    icon: Icons.phone_android,
                    label: "About Device",
                    onTap: onTapAboutDevice ?? () => Navigator.pop(context),
                  ),

                  const SizedBox(height: 8),

                  // Section: Management
                  const _SectionLabel('Management'),

                  ElegantTile(
                    icon: Icons.note_alt_outlined,
                    label: "Feedback",
                    onTap: onTapFeedback ?? () => Navigator.pop(context),
                  ),
                  ElegantTile(
                    icon: Icons.info,
                    label: "Help",
                    onTap: onTapHelp ?? () => Navigator.pop(context),
                  ),
                  ElegantTile(
                    icon: Icons.video_library_outlined,
                    label: "Tech tutorial",
                    onTap: onTapTutorial ?? () => Navigator.pop(context),
                  ),
                  ElegantTile(
                    icon: Icons.history_toggle_off_rounded,
                    label: "Session Logs",
                    onTap: onTapSessionLogs ?? () => Navigator.pop(context),
                  ),
                  ElegantTile(
                    icon: Icons.tune_rounded,
                    label: "Settings",
                    onTap: onTapSettings ?? () => Navigator.pop(context),
                  ),
                  ElegantTile(
                    icon: Icons.info_outline_rounded,
                    label: "About",
                    onTap: onTapAbout ?? () => Navigator.pop(context),
                  ),

                  const Divider(height: 24, indent: 16, endIndent: 16),
                ],
              ),
            ),

            // Footer
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded, size: 18, color: Colors.black45),
                    const SizedBox(width: 8),
                    Text(
                      version,
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.star_border_purple500_rounded, size: 18),
                      label: const Text("Rate us"),
                      style: TextButton.styleFrom(
                        foregroundColor: cs.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          letterSpacing: .4,
          color: Colors.black54,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
