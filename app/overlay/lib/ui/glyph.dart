import 'dart:math' as m;

import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import 'glyph_data.dart';

final Map<String, Path> _cache = {};

Path _path(String key) => _cache.putIfAbsent(key, () {
      final d = kSignGlyphs[key] ?? kPlanetGlyphs[key] ?? '';
      return parseSvgPathData(d);
    });

/// Burç ya da gezegen sembolü (vektör çizim)
class Glyph extends StatelessWidget {
  final String id;
  final double size;
  final Color color;
  final double stroke;
  const Glyph(this.id, {super.key, this.size = 32, this.color = const Color(0xFFE8C77B), this.stroke = 7});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _GlyphPainter(id, color, stroke));
}

class _GlyphPainter extends CustomPainter {
  final String id;
  final Color color;
  final double stroke;
  _GlyphPainter(this.id, this.color, this.stroke);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100.0;
    canvas.save();
    canvas.scale(s);
    canvas.drawPath(
      _path(id),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.id != id || old.color != color || old.stroke != stroke;
}

/// Haritada vb. kullanmak için yalnızca Path döndürür (100 birimlik kutu)
Path glyphPath(String id) => _path(id);

/// Yıldızlı gece arka planı
class StarfieldBackground extends StatelessWidget {
  final Widget child;
  const StarfieldBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      const Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.6, -1.1),
              radius: 1.6,
              colors: [Color(0xFF2A1F52), Color(0xFF120E22), Color(0xFF0B0915)],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        ),
      ),
      const Positioned.fill(child: CustomPaint(painter: _StarPainter())),
      child,
    ]);
  }
}

class _StarPainter extends CustomPainter {
  const _StarPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final r = m.Random(42);
    final p = Paint();
    for (var i = 0; i < 140; i++) {
      final x = r.nextDouble() * size.width;
      final y = r.nextDouble() * size.height;
      final big = r.nextDouble() < 0.08;
      final a = 0.15 + r.nextDouble() * (big ? 0.6 : 0.35);
      p.color = Colors.white.withValues(alpha: a);
      canvas.drawCircle(Offset(x, y), big ? 1.4 : 0.7 + r.nextDouble() * 0.5, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
