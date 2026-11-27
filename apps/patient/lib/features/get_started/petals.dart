import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../core/theme/tokens.dart';

/// A handful of marigold petals thrown up when something good happens (a code verified): they rise, turn, and drift
/// down as they fade, in 1.6 s. Drawn, never emoji; nothing with reduced motion (GI-62).
class PetalBurst extends StatelessWidget {
  const PetalBurst({super.key, required this.time, required this.firedAt, required this.origin, this.reduced = false});

  /// Seconds on the screen's clock.
  final ValueListenable<double> time;

  /// When the petals were thrown (null: not yet).
  final double? firedAt;

  /// Where they come from, in this widget's coordinates.
  final Offset origin;
  final bool reduced;

  @override
  Widget build(BuildContext context) {
    if (reduced || firedAt == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: ExcludeSemantics(
        child: CustomPaint(painter: _PetalPainter(time, firedAt!, origin), size: Size.infinite),
      ),
    );
  }
}

class _PetalPainter extends CustomPainter {
  _PetalPainter(this.time, this.firedAt, this.origin) : super(repaint: time);
  final ValueListenable<double> time;
  final double firedAt;
  final Offset origin;

  static const _life = 1.6;
  static final _petals = List.generate(22, (i) {
    final r = math.Random(31 + i * 7);
    final angle = -math.pi / 2 + (r.nextDouble() - .5) * 2.6; // mostly upwards, fanning out
    final speed = 380 + r.nextDouble() * 360;
    return (
      vx: math.cos(angle) * speed,
      vy: math.sin(angle) * speed,
      spin: (r.nextDouble() - .5) * 9,
      size: 9 + r.nextDouble() * 7,
      colour: i % 3 == 0 ? AdColors.marigold : (i % 3 == 1 ? AdColors.haldi : AdColors.vermilion),
      start: r.nextDouble() * .08,
    );
  });

  static final _outline = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2
    ..color = AdColors.ink;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value - firedAt;
    if (t < 0 || t > _life) return;
    for (final p in _petals) {
      final s = t - p.start;
      if (s <= 0) continue;
      // thrown up, slowed by the air, pulled down
      final drag = (1 - math.exp(-2.2 * s)) / 2.2;
      final x = origin.dx + p.vx * drag;
      final y = origin.dy + p.vy * drag + 620 * s * s / 2;
      final fade = (1 - ((s - _life * .55) / (_life * .45)).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * s);
      final petal = Path()
        ..moveTo(0, -p.size)
        ..quadraticBezierTo(p.size * .62, -p.size * .2, 0, p.size * .55)
        ..quadraticBezierTo(-p.size * .62, -p.size * .2, 0, -p.size)
        ..close();
      canvas.drawPath(petal, Paint()..color = p.colour.withValues(alpha: fade));
      canvas.drawPath(petal, _outline..color = AdColors.ink.withValues(alpha: fade * .9));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_PetalPainter old) => old.firedAt != firedAt || old.origin != origin;
}
