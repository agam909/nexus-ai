import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A hexagonal brand mark with a glowing AI icon.
class HexLogo extends StatelessWidget {
  const HexLogo({
    super.key,
    this.size = 40,
    this.icon = Icons.hub_rounded,
    this.label,
  });

  final double size;
  final IconData icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hex = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _HexPainter(
          fill: scheme.primary.withValues(alpha: 0.12),
          stroke: scheme.primary,
          glow: scheme.primary.withValues(alpha: 0.45),
        ),
        child: Center(
          child: Icon(
            icon,
            color: scheme.primary,
            size: size * 0.5,
          ),
        ),
      ),
    );

    if (label == null) return hex;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        hex,
        const SizedBox(width: 12),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label!,
              style: TextStyle(
                fontSize: size * 0.42,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: scheme.onSurface,
              ),
            ),
            Text(
              'Knowledge Intelligence',
              style: TextStyle(
                fontSize: size * 0.26,
                color: AppColors.cyan,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HexPainter extends CustomPainter {
  _HexPainter({required this.fill, required this.stroke, required this.glow});

  final Color fill;
  final Color stroke;
  final Color glow;

  Path _hexPath(Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy);
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i - math.pi / 2;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _hexPath(size);
    canvas.drawPath(
      path,
      Paint()
        ..color = glow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _HexPainter old) =>
      old.fill != fill || old.stroke != stroke || old.glow != glow;
}
