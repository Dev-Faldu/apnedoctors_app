import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../core/motion/keyframes.dart';
import '../../core/theme/tokens.dart';

/// The marigold toran across the top of Get started (G03 `svg.toran`, viewBox 390 × 56 stretched to the width):
/// a brown string, seven marigolds (haldi and orange) and six mango leaves. The whole garland sways ±0.8° from its
/// middle over 5.2 s; each leaf swings ±7° from its stalk over 3.4 s, every other leaf 0.7 s later.
class Toran extends StatelessWidget {
  const Toran({super.key, required this.time, this.reduced = false});

  /// Seconds since the screen opened.
  final ValueListenable<double> time;
  final bool reduced;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: 56,
      width: double.infinity,
      child: CustomPaint(painter: _ToranPainter(time, reduced)),
    ),
  );
}

class _ToranPainter extends CustomPainter {
  _ToranPainter(this.time, this.reduced) : super(repaint: reduced ? null : time);
  final ValueListenable<double> time;
  final bool reduced;

  static const _leafX = [47.1, 106.3, 165.4, 224.6, 283.7, 342.9];
  static const _leafTop = [14.5, 21.6, 25.1, 25.1, 21.6, 14.5];
  static const _flowerX = [17.6, 76.7, 135.9, 195.0, 254.1, 313.3, 372.4];
  static const _flowerY = [8.7, 17.5, 22.7, 24.5, 22.7, 17.5, 8.7];

  static final _swing = Keyframes.of(const [(0, -1), (.5, 1), (1, -1)]);

  static final _string = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6
    ..color = AdColors.toranString;
  static final _ink13 = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.3
    ..color = AdColors.ink;
  static final _ink14 = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4
    ..color = AdColors.ink;

  double _deg(double t, double period, double amount, {double delay = 0}) {
    if (reduced) return 0;
    final a = CssAnim(period, delay: delay, infinite: true, fill: Fill.none, curve: cssEaseInOut);
    return (a.sample(t, _swing) ?? 0) * amount * math.pi / 180;
  }

  static void _rotateAbout(Canvas canvas, double x, double y, double angle) {
    canvas
      ..translate(x, y)
      ..rotate(angle)
      ..translate(-x, -y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    canvas.save();
    canvas.scale(size.width / 390, 1); // preserveAspectRatio="none"
    _rotateAbout(canvas, 195, 0, _deg(t, 5.2, .8));

    canvas.drawPath(
      Path()
        ..moveTo(-12, 3)
        ..quadraticBezierTo(195, 46, 402, 3),
      _string,
    );

    for (var i = 0; i < _leafX.length; i++) {
      final x = _leafX[i], y = _leafTop[i];
      final leaf = Path()
        ..moveTo(x, y)
        ..cubicTo(x - 4, y + 7, x - 3, y + 13, x, y + 18)
        ..cubicTo(x + 3, y + 13, x + 4, y + 7, x, y)
        ..close();
      canvas.save();
      _rotateAbout(canvas, x, y, _deg(t, 3.4, 7, delay: i.isOdd ? .7 : 0));
      canvas
        ..drawPath(leaf, Paint()..color = AdColors.green)
        ..drawPath(leaf, _ink13)
        ..restore();
    }

    for (var i = 0; i < _flowerX.length; i++) {
      final c = Offset(_flowerX[i], _flowerY[i]);
      canvas
        ..drawCircle(c, 6.5, Paint()..color = i.isEven ? AdColors.haldi : AdColors.marigold)
        ..drawCircle(c, 6.5, _ink14)
        ..drawCircle(c, 1.9, Paint()..color = AdColors.toranString);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ToranPainter old) => old.reduced != reduced;
}
