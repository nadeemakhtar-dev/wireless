import 'dart:ui';
import 'package:flutter/material.dart';

class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.borderRadius = 20,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  });

  final VoidCallback onPressed;
  final String label;
  final IconData? icon;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Tunable opacities for light/dark
    final glassFill = isDark ? 0.10 : 0.12;
    final glassHighlight = isDark ? 0.20 : 0.28;
    final borderOpacity = isDark ? 0.28 : 0.25;
    final shadowOpacity = isDark ? 0.25 : 0.10;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        children: [
          // The blur that makes it "glass"
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: const SizedBox.expand(),
          ),
          // The translucent surface with gradient + border + shadow
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(glassHighlight),
                  Colors.white.withOpacity(glassFill),
                ],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(borderOpacity),
              ),
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(shadowOpacity),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                splashColor: Colors.white.withOpacity(0.20),
                highlightColor: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(borderRadius),
                child: Padding(
                  padding: padding,
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: Colors.white,
                      shadows: [
                        Shadow(blurRadius: 4, color: Colors.black26, offset: Offset(0, 1)),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 16, color: Colors.white),
                          const SizedBox(width: 8),
                        ],
                        Text(label.toUpperCase()),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Subtle top specular highlight line
          Positioned(
            top: 1,
            left: 1,
            right: 1,
            child: Container(
              height: 1.2,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.white.withOpacity(0.65),
                    Colors.white.withOpacity(0.25),
                    Colors.white.withOpacity(0.65),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
