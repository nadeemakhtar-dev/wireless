import 'dart:ui';
import 'package:flutter/material.dart';

class RadarFooter extends StatelessWidget {
  const RadarFooter({
    required this.scanning,
    required this.near,
    required this.far,
    required this.onToggle,
  });

  final bool scanning;
  final int near;
  final int far;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + (bottomPad > 0 ? bottomPad - 4 : 6)),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF111418).withOpacity(.92), const Color(0xFF171B22).withOpacity(.88)]
                  : [Colors.white.withOpacity(.96), const Color(0xFFF7F8FA).withOpacity(.94)],
            ),
            border: Border(top: BorderSide(color: (isDark ? Colors.white : Colors.black).withOpacity(isDark ? .08 : .06))),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? .25 : .10),
                blurRadius: 16,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Left: device counters
              _CounterChip(
                icon: Icons.near_me_rounded,
                label: 'Near',
                count: near,
                color: cs.primary,
              ),
              const SizedBox(width: 8),
              _CounterChip(
                icon: Icons.waves_rounded,
                label: 'Far',
                count: far,
                color: cs.secondary,
              ),

              const Spacer(),

              // Center: scanning state (subtle)
              if (scanning) ...[
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text('Scan...', style: TextStyle(color: cs.onSurface.withOpacity(.8), fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
              ],

              // Right: primary action
             scanning ?   _GlassActionButton(
                label: 'Stop' ,
                icon: Icons.stop_rounded ,
                onPressed: onToggle,
                emphasize: !scanning, // brighter when ready to start
              )  : SizedBox.shrink() ,
            ],
          ),
        ),
      ),
    );
  }
}

class _CounterChip extends StatelessWidget {
  const _CounterChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: cs.surface.withOpacity(.65),
        border: Border.all(color: cs.outlineVariant.withOpacity(.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text('$label ',
              style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface.withOpacity(.85))),
          Text('$count',
              style: TextStyle(fontFeatures: const [FontFeature.tabularFigures()], color: cs.onSurface)),
        ],
      ),
    );
  }
}

class _GlassActionButton extends StatelessWidget {
  const _GlassActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.emphasize = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: const SizedBox(height: 44)),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.blueGrey.shade800.withOpacity(isDark ? (emphasize ? .20 : .12) : (emphasize ? .30 : .22)),
              border: Border.all(color: Colors.blueGrey.shade600.withOpacity(.25)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? .22 : .12),
                  blurRadius: 12, offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
                Text(label.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .5,
                    )),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              splashColor: Colors.white.withOpacity(.15),
              highlightColor: Colors.white.withOpacity(.08),
              child: const SizedBox(height: 44),
            ),
          ),
        ],
      ),
    );
  }
}
