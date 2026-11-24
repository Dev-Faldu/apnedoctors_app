import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';
import 'living_a.dart';
import 'lockup_glyphs.g.dart';
import 'path_ops.dart';

/// The ApneDoctors lockup: the logo "a" stands in for the capital A, then "pne" in vermilion and
/// "Doctors" in ink (Kaushan Script outlines, so no "A" is ever typed in the script face).
class Lockup extends StatelessWidget {
  const Lockup({super.key, this.height = LockupGlyphs.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final s = height / LockupGlyphs.height;
    return Semantics(
      label: 'ApneDoctors',
      image: true,
      child: SizedBox(
        width: LockupGlyphs.width * s,
        height: height,
        child: CustomPaint(painter: _LockupPainter(s)),
      ),
    );
  }
}

final Path _pne = pathFromOps(LockupGlyphs.pne);
final Path _doctors = pathFromOps(LockupGlyphs.doctors);

class _LockupPainter extends CustomPainter {
  _LockupPainter(this.s);
  final double s;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(s);
    canvas.save();
    canvas.translate(LockupGlyphs.logoX, LockupGlyphs.logoY);
    canvas.scale(LockupGlyphs.logoScale);
    paintLivingA(canvas, AFace.awake);
    canvas.restore();
    canvas.drawPath(_pne, Paint()..color = AdColors.vermilion);
    canvas.drawPath(_doctors, Paint()..color = AdColors.ink);
  }

  @override
  bool shouldRepaint(_LockupPainter old) => old.s != s;
}
