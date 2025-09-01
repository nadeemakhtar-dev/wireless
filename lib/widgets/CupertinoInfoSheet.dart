// import at top
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CupertinoInfoSheet extends StatefulWidget {
  const CupertinoInfoSheet({
    super.key,
    required this.title,
    required this.info,
    required this.primaryColor,
    this.onCheck,  // async checker; returns true if OK
    this.onClose,  // optional custom close
  });

  final String title;
  final Map<String, String> info;
  final Color primaryColor;

  /// Called when user taps "Check". Return true for success.
  final Future<bool> Function()? onCheck;

  /// Called when user taps "Close" (defaults to Navigator.pop)
  final VoidCallback? onClose;

  @override
  State<CupertinoInfoSheet> createState() => _CupertinoInfoSheetState();
}

class _CupertinoInfoSheetState extends State<CupertinoInfoSheet> {
  bool _busy = false;
  bool? _ok; // null = idle, true = success, false = fail

  void _handleClose() {
    widget.onClose != null
        ? widget.onClose!()
        : Navigator.of(context).maybePop();
  }

  Future<void> _handleCheck() async {
    if (widget.onCheck == null || _busy) return;
    setState(() { _busy = true; _ok = null; });
    try {
      final ok = await widget.onCheck!();
      HapticFeedback.lightImpact();
      if (!mounted) return;
      setState(() { _ok = ok; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(ok ? 'Check passed' : 'Check failed'),
          duration: const Duration(milliseconds: 1200),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() { _ok = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Check error'),
          duration: Duration(milliseconds: 1200),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() { _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF0F1115).withOpacity(.92),
                const Color(0xFF151821).withOpacity(.88)]
                  : [Colors.white.withOpacity(.96),
                const Color(0xFFF7F8FA).withOpacity(.94)],
            ),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black)
                  .withOpacity(isDark ? .08 : .06),
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 28, spreadRadius: 2, offset: const Offset(0, -10),
                color: Colors.black.withOpacity(isDark ? .35 : .15),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // grabber
                    Container(
                      width: 44, height: 4, margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black).withOpacity(.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),

                    // header
                    Row(
                      children: [
                        _GradientIcon(
                          icon: CupertinoIcons.device_phone_portrait,
                          color: widget.primaryColor, size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800,
                              letterSpacing: .2, color: cs.onSurface,
                            ),
                          ),
                        ),
                        _IconAction(
                          tooltip: 'Copy all',
                          icon: CupertinoIcons.doc_on_doc,
                          onTap: () async {
                            final lines = widget.info.entries
                                .map((e) => '${e.key}: ${e.value}').join('\n');
                            await Clipboard.setData(ClipboardData(text: lines));
                            HapticFeedback.selectionClick();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                behavior: SnackBarBehavior.floating,
                                content: Text('Device info copied'),
                                duration: Duration(milliseconds: 1200),
                              ),
                            );
                          },
                        ),
                        _IconAction(
                          tooltip: 'Close',
                          icon: CupertinoIcons.xmark_circle_fill,
                          onTap: _handleClose,
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // list
                    LayoutBuilder(
                      builder: (_, __) {
                        final maxH = (MediaQuery.of(context).size.height * 0.55)
                            .clamp(280.0, 480.0);
                        return ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: maxH),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const BouncingScrollPhysics(),
                            itemCount: widget.info.length,
                            separatorBuilder: (_, __) => _HairlineDivider(
                              color: cs.outlineVariant.withOpacity(.35),
                            ),
                            itemBuilder: (context, i) {
                              final k = widget.info.keys.elementAt(i);
                              final v = widget.info[k]!;
                              final icon = _iconForKey(k);
                              final mono = _looksLikeCodey(v);
                              return _InfoRow(
                                leading: icon,
                                label: k,
                                value: v,
                                primaryColor: widget.primaryColor,
                                mono: mono,
                                onCopy: () async {
                                  await Clipboard.setData(ClipboardData(text: v));
                                  HapticFeedback.selectionClick();
                                },
                              );
                            },
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 14),

                    // actions: Check + Close
                    Row(
                      children: [
                        Expanded(
                          child: _GlassButton(
                            label: 'Close',
                            icon: CupertinoIcons.clear_circled,
                            color: Colors.blueGrey.shade700,
                            onPressed: _busy ? null : _handleClose,
                            busy: _busy,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Expanded(
                        //   child: _GhostButton(
                        //     label: 'Close',
                        //     icon: Icons.close_rounded,
                        //     onPressed: _handleClose,
                        //   ),
                        // ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ------------------ Pieces ------------------ */

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.leading,
    required this.label,
    required this.value,
    required this.primaryColor,
    required this.mono,
    required this.onCopy,
  });

  final IconData leading;
  final String label;
  final String value;
  final Color primaryColor;
  final bool mono;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // icon badge
          Container(
            width: 34, height: 34, alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                colors: [primaryColor.withOpacity(.18), primaryColor.withOpacity(.10)],
              ),
              border: Border.all(color: primaryColor.withOpacity(.28), width: .7),
            ),
            child: Icon(leading, size: 18, color: primaryColor),
          ),
          const SizedBox(width: 12),
          // texts
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: .2,
                      color: cs.onSurface.withOpacity(.72),
                    )),
                const SizedBox(height: 4),
                SelectableText(
                  value,
                  style: TextStyle(
                    fontSize: 15.0, height: 1.25, color: cs.onSurface,
                    fontFeatures: mono ? const [FontFeature.tabularFigures()] : const [],
                    fontFamily: mono ? 'SF Mono' : null,
                  ),
                ),
              ],
            ),
          ),
          _IconAction(
            tooltip: 'Copy',
            icon: CupertinoIcons.doc_on_doc_fill,
            onTap: onCopy,
          ),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.tooltip, required this.icon, required this.onTap});
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        highlightColor: cs.primary.withOpacity(.10),
        splashColor: cs.primary.withOpacity(.14),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Icon(icon, size: 20, color: cs.onSurface.withOpacity(.80)),
        ),
      ),
    );
  }
}

class _HairlineDivider extends StatelessWidget {
  const _HairlineDivider({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Container(height: 1, color: color);
}

class _GradientIcon extends StatelessWidget {
  const _GradientIcon({required this.icon, required this.color, this.size = 22});
  final IconData icon; final Color color; final double size;
  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (r) => LinearGradient(
        colors: [color, color.withOpacity(.55)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ).createShader(r),
      child: Icon(icon, size: size, color: Colors.white),
    );
  }
}

/// Primary glass CTA (with busy & icon)
class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.label,
    required this.onPressed,
    required this.color,
    this.icon,
    this.radius = 14,
    this.height = 44,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;
  final double radius;
  final double height;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        alignment: Alignment.center,
        children: [
          BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: SizedBox(height: height, width: double.infinity),
          ),
          Container(
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Colors.blueGrey.withOpacity(isDark ? .18 : .30),
                  Colors.blueGrey.withOpacity(isDark ? .10 : .18)],
              ),
              border: Border.all(color: Colors.blueGrey.shade700.withOpacity(.28), width: .8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? .25 : .10),
                  blurRadius: 14, offset: const Offset(0, 6),
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
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: busy
                        ? const CupertinoActivityIndicator()
                        : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 18, color: color),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          label.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w800,
                            letterSpacing: .6, color: Colors.blueGrey,
                            shadows: [Shadow(blurRadius: 4, color: Colors.black26, offset: Offset(0, 1))],
                          ),
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
    );
  }
}

/// Secondary ghost button (clean outline)
class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.radius = 14,
    this.height = 44,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final double radius;
  final double height;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: cs.onSurface.withOpacity(.80)),
        label: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: .6,
            color: cs.onSurface,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: cs.outlineVariant.withOpacity(.45)),
          backgroundColor: cs.surface.withOpacity(.60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
      ),
    );
  }
}

/* ---------- Heuristics: icons & value styles ---------- */

IconData _iconForKey(String key) {
  final k = key.toLowerCase();
  if (k.contains('manufacturer')) return Icons.factory_outlined;
  if (k.contains('model')) return Icons.devices;
  if (k.contains('device') && k.contains('id')) return CupertinoIcons.number;
  if (k.contains('id')) return CupertinoIcons.number;
  if (k.contains('mac')) return CupertinoIcons.barcode_viewfinder;
  if (k.contains('uuid')) return CupertinoIcons.tag;
  if (k.contains('service data') || k.contains('payload')) return CupertinoIcons.chart_bar_square;
  if (k.contains('rssi') || k.contains('signal')) return CupertinoIcons.waveform_path_ecg;
  if (k.contains('battery')) return CupertinoIcons.battery_75_percent;
  if (k.contains('firmware') || k.contains('version')) return CupertinoIcons.gear_alt_fill;
  if (k.contains('tx') && k.contains('power')) return CupertinoIcons.bolt_fill;
  if (k.contains('last') && k.contains('seen')) return CupertinoIcons.clock;
  if (k.contains('os')) return CupertinoIcons.desktopcomputer;
  if (k.contains('address')) return CupertinoIcons.location;
  return CupertinoIcons.info_circle;
}

bool _looksLikeCodey(String v) {
  final s = v.trim();
  final hasHex = RegExp(r'^(0x)?[0-9a-fA-F\-:\s]+$').hasMatch(s);
  final longToken = s.length > 16 && !s.contains(' ');
  final hasUuid = RegExp(r'[0-9a-fA-F]{8}-').hasMatch(s);
  return hasHex || longToken || hasUuid;
}
