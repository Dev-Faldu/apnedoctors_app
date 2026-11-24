import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// The living "a": the ApneDoctors logo as a character.
///
/// Geometry is the 160-unit logo box shifted so the bowl centre is the origin:
/// bowl = circle r 45, stroke 16; stem = `M45 -44 V26 Q45 46 64 46`, stroke 16, round caps;
/// eyes = ink circles r 8 at (-16, -6) and (16, -6).
abstract final class AShape {
  static const bowlRadius = 45.0;
  static const stroke = 16.0;
  static const eyeRadius = 8.0;
  static const eyeY = -6.0;
  static const eyeDx = 16.0;

  /// Bounds including the stroke.
  static const bounds = Rect.fromLTRB(-53, -52, 72, 54);

  static final Path stem = Path()
    ..moveTo(45, -44)
    ..lineTo(45, 26)
    ..quadraticBezierTo(45, 46, 64, 46);
}

/// How the face is drawn. On the splash the blush is a soft vermilion wash under the eyes; in the
/// Welcome doorway it is two pink cheeks that come with the happy eyes.
enum BlushStyle { wash, cheeks }

/// One frame of the a's face. Opacities are 0–1 and cross-fade between eye shapes.
@immutable
class AFace {
  const AFace({
    this.open = 1,
    this.happy = 0,
    this.asleep = 0,
    this.blush = 0,
    this.gaze = Offset.zero,
    this.lid = 1,
    this.blushStyle = BlushStyle.wash,
    this.happyLift = 14,
  });

  /// Open eyes (ink dots).
  final double open;

  /// Happy, closed eyes (upward curves).
  final double happy;

  /// Asleep (downward curves).
  final double asleep;

  /// Blush opacity.
  final double blush;

  /// Where the open eyes look, in a units.
  final Offset gaze;

  /// Eyelid: 1 open, 0.1 nearly shut (scaleY of the open eyes around their centre).
  final double lid;

  final BlushStyle blushStyle;

  /// Height of the happy-eye curve's control point (14 on the splash, 15 in the doorway).
  final double happyLift;

  static const awake = AFace();
}

final _bodyPaint = Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = AShape.stroke
  ..strokeCap = StrokeCap.round
  ..isAntiAlias = true;

/// Paints the a in its own units (bowl centre at the canvas origin).
void paintLivingA(Canvas canvas, AFace face, {Color body = AdColors.vermilion, Color eyes = AdColors.ink}) {
  _bodyPaint.color = body;
  canvas.drawCircle(Offset.zero, AShape.bowlRadius, _bodyPaint);
  canvas.drawPath(AShape.stem, _bodyPaint);

  if (face.blushStyle == BlushStyle.wash && face.blush > 0) {
    final p = Paint()..color = AdColors.vermilion.withValues(alpha: .22 * face.blush);
    canvas.drawOval(Rect.fromCenter(center: const Offset(-25, 12), width: 16, height: 9), p);
    canvas.drawOval(Rect.fromCenter(center: const Offset(25, 12), width: 16, height: 9), p);
  }

  if (face.open > 0) {
    canvas.save();
    canvas.translate(face.gaze.dx, face.gaze.dy);
    if (face.lid != 1) {
      canvas.translate(0, AShape.eyeY);
      canvas.scale(1, face.lid);
      canvas.translate(0, -AShape.eyeY);
    }
    final p = Paint()..color = eyes.withValues(alpha: eyes.a * face.open);
    canvas.drawCircle(const Offset(-AShape.eyeDx, AShape.eyeY), AShape.eyeRadius, p);
    canvas.drawCircle(const Offset(AShape.eyeDx, AShape.eyeY), AShape.eyeRadius, p);
    canvas.restore();
  }

  if (face.happy > 0) {
    final lift = -face.happyLift;
    final path = Path()
      ..moveTo(-25, -3)
      ..quadraticBezierTo(-16, lift, -7, -3)
      ..moveTo(7, -3)
      ..quadraticBezierTo(16, lift, 25, -3);
    canvas.drawPath(path, _curvePaint(eyes, face.happy));
  }

  if (face.asleep > 0) {
    final path = Path()
      ..moveTo(-25, -5)
      ..quadraticBezierTo(-16, 3, -7, -5)
      ..moveTo(7, -5)
      ..quadraticBezierTo(16, 3, 25, -5);
    canvas.drawPath(path, _curvePaint(eyes, face.asleep));
  }

  if (face.blushStyle == BlushStyle.cheeks && face.happy > 0) {
    final p = Paint()..color = AdColors.pink.withValues(alpha: face.happy);
    canvas.drawCircle(const Offset(-27, 11), 6, p);
    canvas.drawCircle(const Offset(27, 11), 6, p);
  }
}

Paint _curvePaint(Color c, double alpha) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = 7
  ..strokeCap = StrokeCap.round
  ..color = c.withValues(alpha: c.a * alpha);

/// A still a, for icons and static marks.
class LivingAMark extends StatelessWidget {
  const LivingAMark({super.key, this.size = 48, this.face = AFace.awake});

  /// Width of the a's bounds.
  final double size;
  final AFace face;

  @override
  Widget build(BuildContext context) {
    final s = size / AShape.bounds.width;
    return SizedBox(
      width: size,
      height: AShape.bounds.height * s,
      child: CustomPaint(painter: _MarkPainter(face, s)),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.face, this.s);
  final AFace face;
  final double s;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(s);
    canvas.translate(-AShape.bounds.left, -AShape.bounds.top);
    paintLivingA(canvas, face);
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.face != face || old.s != s;
}
