import 'dart:async';
import 'dart:ui';
import 'dart:math' as math; // NEW: for distance math
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:wireless/helpers/MenuInfo.dart';


class DeviceTileExpandable extends StatefulWidget {
  const DeviceTileExpandable({
    super.key,
    required this.device,
    required this.color,
    required this.onConnect,
    required this.onRaw,
    required this.onSave,
    required this.subtitleText, // NEW: pass from ScanScreen
    this.onClose, // optional close handler
    this.rssi, // NEW: optional, for the signal badge only
    // NEW: Provide a way to start a stream (e.g., notifications)
    this.onStartStream, // returns a Stream<List<int>>
  });

  final DiscoveredDevice device;
  final Color color;
  final VoidCallback onConnect;
  final VoidCallback onRaw;
  final VoidCallback onSave;
  final VoidCallback? onClose;

  // NEW
  final String subtitleText;
  final int? rssi;
  /// Start notifications/indications (or any data stream) for this device.
  /// Return a Stream<List<int>> of incoming payloads.
  final Future<Stream<List<int>>?> Function()? onStartStream;

  @override
  State<DeviceTileExpandable> createState() => _DeviceTileExpandableState();
}

class _DeviceTileExpandableState extends State<DeviceTileExpandable> {
  StreamSubscription<List<int>>? _sub;
  List<int>? _latest;
  bool _reading = false;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    if (_reading) return;
    if (widget.onStartStream == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No stream available. Wire onStartStream.')),
      );
      return;
    }
    final stream = await widget.onStartStream!.call();
    if (stream == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to start stream')),
      );
      return;
    }
    setState(() => _reading = true);
    _sub = stream.listen((data) {
      setState(() => _latest = data);
    }, onError: (e) {
      setState(() => _reading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stream error: $e')),
      );
    }, onDone: () {
      setState(() => _reading = false);
    });
  }

  Future<void> _stop() async {
    await _sub?.cancel();
    _sub = null;
    setState(() => _reading = false);
  }

  String _toHex(List<int>? bytes) {
    if (bytes == null || bytes.isEmpty) return '—';
    final b = StringBuffer();
    for (final v in bytes) {
      b.write(v.toRadixString(16).padLeft(2, '0').toUpperCase());
      b.write(' ');
    }
    return b.toString().trimRight();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = widget.device.name.isNotEmpty ? widget.device.name : 'N/A'; // CHANGED: N/A
    final manu = parseManufacturer(widget.device.manufacturerData);
    final serviceUuids = widget.device.serviceUuids;
    final serviceData = widget.device.serviceData;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: Color.alphaBlend(cs.onSurface.withOpacity(.03), cs.surface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant.withOpacity(.35)),
      ),
      child: Stack(
        children: [
          // Slim accent rail
          Positioned.fill(
            left: 0,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 6,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                ),
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
                expansionTileTheme: ExpansionTileThemeData(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  collapsedBackgroundColor: Colors.transparent,
                  backgroundColor: Colors.transparent,
                  iconColor: cs.primary,
                  collapsedIconColor: cs.outline,
                ),
              ),
              child: ExpansionTile(
                leading: _SignalBadge(rssi: widget.device.rssi, color: widget.color),
                title: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .2,
                    color: cs.onSurface,
                  ),
                ),
                // CHANGED: subtitle now shows ID + Approx. Distance (meters, 2 decimals)
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.device.id,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      widget.subtitleText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: cs.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _GlassPillButton(
                      label: 'Connect',
                      icon: Icons.link_rounded,
                      color: widget.color,
                      dense: true,
                      onPressed: widget.onConnect,
                    ),
                    const SizedBox(width: 8),
                    // _IconGhostButton(
                    //   icon: Icons.close_rounded,
                    //   tooltip: 'Close',
                    //   onTap: onClose ?? () => Navigator.of(context).maybePop(),
                    // ),
                  ],
                ),
                children: [
                  const SizedBox(height: 6),
                  _SpecRow(
                    icon: Icons.factory_outlined,
                    color: widget.color,
                    label: 'Manufacturer',
                    primary: manu.label,
                    secondary: manu.payloadHex != null ? 'Payload: ${manu.payloadHex}' : null,
                    monoSecondary: true,
                  ),
                  const SizedBox(height: 10),

                  if (serviceUuids.isNotEmpty) ...[
                    _SpecRow(
                      icon: Icons.tag_rounded,
                      color: widget.color,
                      label: 'Service UUIDs',
                      widget: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: serviceUuids
                            .map((u) => _Chip(monoText: u.toString(), color: widget.color))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  if (serviceData.isNotEmpty) ...[
                    _SpecRow(
                      icon: Icons.dataset_outlined,
                      color: widget.color,
                      label: 'Service Data',
                      primary: serviceData.entries
                          .map((e) => '${e.key}: ${e.value.length} bytes')
                          .join(' • '),
                      monoPrimary: true,
                    ),
                    const SizedBox(height: 10),
                  ],
                  // --- LIVE DATA PANEL ---
                  _SpecRow(
                    icon: _reading ? Icons.podcasts_rounded : Icons.podcasts_outlined,
                    color: widget.color,
                    label: _reading ? 'Live Data (streaming)' : 'Live Data',
                    primary: _toHex(_latest),
                    monoPrimary: true,
                    widget: Row(
                      children: [
                        Expanded(
                          child: _GlassPillButton(
                            label: _reading ? 'Stop' : 'Start',
                            icon: _reading ? Icons.stop_circle_rounded : Icons.play_arrow_rounded,
                            color: _reading ? Colors.amber : widget.color,
                            onPressed: _reading ? _stop : _start,
                            dense: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _GlassPillButton(
                            label: 'RAW',
                            icon: Icons.auto_graph_rounded,
                            color: widget.color,
                            onPressed: widget.onRaw,
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  _ActionBar(
                    children: [
                      _GlassPillButton(
                        label: 'Save',
                        icon: Icons.bookmark_add_outlined,
                        color: widget.color,
                        onPressed: widget.onSave,   // 👈 already provided from parent
                      ),
                      _GlassPillButton(
                        label: 'RAW',
                        icon: Icons.auto_graph_rounded,
                        color: widget.color,
                        onPressed: widget.onRaw,
                      ),
                      _GlassPillButton(
                        label: 'Close',
                        icon: Icons.check_rounded,
                        color: cs.primary.withOpacity(.85),
                        onPressed: widget.onClose ?? () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* -------------------- Premium Bits -------------------- */

class _SignalBadge extends StatelessWidget {
  const _SignalBadge({required this.rssi, required this.color});
  final int? rssi; // now nullable
  final Color color;

  @override
  Widget build(BuildContext context) {
    final strength = rssi; // map however you like
    final cs = Theme.of(context).colorScheme;
    final bg = color.withOpacity(.14);
    final fg = color;
    final text = (rssi == null) ? '—' : '${rssi!}';

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bg, cs.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(.25)),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _IconGhostButton extends StatelessWidget {
  const _IconGhostButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 20,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant.withOpacity(.45)),
            color: cs.surface.withOpacity(.6),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: cs.onSurface.withOpacity(.75)),
        ),
      ),
    );
  }
}

class _GlassPillButton extends StatelessWidget {
  const _GlassPillButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.dense = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final h = dense ? 34.0 : 42.0;
    final radius = dense ? 16.0 : 18.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        children: [
          BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12), child: SizedBox(height: h)),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.black12.withOpacity(isDark ? .18 : .30),
                  Colors.black54.withOpacity(isDark ? .10 : .18),
                ],
              ),
              border: Border.all(color: Colors.blueGrey.shade800.withOpacity(.58), width: .8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? .25 : .10),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(radius),
                splashColor: color.withOpacity(.15),
                highlightColor: color.withOpacity(.08),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: dense ? 12 : 14,
                    vertical: dense ? 8 : 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: dense ? 16 : 18, color: color),
                      const SizedBox(width: 8),
                      Text(
                        label.toUpperCase(),
                        style: TextStyle(
                          fontSize: dense ? 11.5 : 12.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .6,
                          color: Colors.white,
                          shadows: const [
                            Shadow(blurRadius: 4, color: Colors.black26, offset: Offset(0, 1)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow({
    required this.icon,
    required this.color,
    required this.label,
    this.primary,
    this.secondary,
    this.widget,
    this.monoPrimary = false,
    this.monoSecondary = false,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String? primary;
  final String? secondary;
  final Widget? widget;
  final bool monoPrimary;
  final bool monoSecondary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon badge
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              colors: [color.withOpacity(.18), color.withOpacity(.10)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: color.withOpacity(.28), width: .7),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),

        // Content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .2,
                    color: cs.onSurface.withOpacity(.72),
                  )),
              const SizedBox(height: 4),
              if (widget != null) widget!,
              if (primary != null)
                SelectableText(
                  primary!,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.25,
                    color: cs.onSurface,
                    fontFeatures: monoPrimary ? const [FontFeature.tabularFigures()] : const [],
                    fontFamily: monoPrimary ? 'SF Mono' : null,
                  ),
                ),
              if (secondary != null) ...[
                const SizedBox(height: 3),
                SelectableText(
                  secondary!,
                  style: TextStyle(
                    fontSize: 12.0,
                    color: cs.onSurfaceVariant,
                    fontFeatures: monoSecondary ? const [FontFeature.tabularFigures()] : const [],
                    fontFamily: monoSecondary ? 'SF Mono' : null,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.monoText, required this.color});
  final String monoText;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: color.withOpacity(isDark ? .16 : .10),
        border: Border.all(color: color.withOpacity(.25), width: .7),
      ),
      child: Text(
        monoText,
        style: const TextStyle(
          fontSize: 11.5,
          fontFeatures: [FontFeature.tabularFigures()],
          fontFamily: 'SF Mono',
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            Expanded(child: children[i]),
            if (i != children.length - 1) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}
