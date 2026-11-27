import 'package:flutter/widgets.dart';

import '../../core/theme/tokens.dart';

/// Small drawn icons from the Get started board (G03), at the board's own geometry. Never emoji.

/// The round "!" before a problem (`.help.bad svg`, 18 × 18 viewBox).
class AlertMark extends StatelessWidget {
  const AlertMark({super.key, this.size = 18, this.color = AdColors.errorText});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size.square(size), painter: _AlertPainter(color)),
  );
}

class _AlertPainter extends CustomPainter {
  const _AlertPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 18);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(const Offset(9, 9), 8, stroke..strokeWidth = 2);
    canvas.drawLine(const Offset(9, 4.8), const Offset(9, 10), stroke..strokeWidth = 2.2);
    canvas.drawCircle(const Offset(9, 13.2), 1.3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_AlertPainter old) => old.color != color;
}

/// The green tick when a number looks right (`.tick`, 26 × 26).
class TickMark extends StatelessWidget {
  const TickMark({super.key, this.size = 26});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Looks right',
    image: true,
    child: CustomPaint(size: Size.square(size), painter: const _TickPainter()),
  );
}

class _TickPainter extends CustomPainter {
  const _TickPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 26);
    canvas.drawCircle(const Offset(13, 13), 13, Paint()..color = AdColors.tick);
    canvas.drawPath(
      Path()
        ..moveTo(7.5, 13.4)
        ..relativeLineTo(3.6, 3.6)
        ..relativeLineTo(7.4, -7.6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = AdColors.white,
    );
  }

  @override
  bool shouldRepaint(_TickPainter old) => false;
}

/// A check in a 24 viewBox (the "code sent" button).
class CheckMark extends StatelessWidget {
  const CheckMark({super.key, this.size = 20, this.color = AdColors.paper});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size.square(size), painter: _CheckPainter(color)),
  );
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    canvas.drawPath(
      Path()
        ..moveTo(5, 12.5)
        ..relativeLineTo(4.5, 4.5)
        ..lineTo(19, 7.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.color != color;
}

/// No signal: a wifi fan crossed out (`.offline svg`, 24 viewBox).
class OfflineMark extends StatelessWidget {
  const OfflineMark({super.key, this.size = 22, this.color = AdColors.paper});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size.square(size), painter: _OfflinePainter(color)),
  );
}

class _OfflinePainter extends CustomPainter {
  const _OfflinePainter(this.color);
  final Color color;

  /// An SVG arc command `a r r 0 0 1 dx dy` from [from].
  static void _arc(Path p, Offset from, double r, Offset by) {
    p.moveTo(from.dx, from.dy);
    p.relativeArcToPoint(by, radius: Radius.circular(r));
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final path = Path();
    _arc(path, const Offset(2.5, 8.8), 14, const Offset(6, -3.2));
    _arc(path, const Offset(13.5, 5.4), 14, const Offset(8, 3.4));
    _arc(path, const Offset(5.8, 12.3), 9, const Offset(3.4, -2));
    _arc(path, const Offset(15.6, 10.6), 9, const Offset(2.6, 1.7));
    _arc(path, const Offset(9.2, 15.6), 4.6, const Offset(5.6, 0));
    path
      ..moveTo(3, 3)
      ..lineTo(21, 21);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
    canvas.drawCircle(const Offset(12, 19.2), 1.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_OfflinePainter old) => old.color != color;
}

/// The board's back chevron (`M15 5l-7 7 7 7`, stroke 2.4) at 26 px, centred in a 48 × 48 touch area.
class KpBackButton extends StatelessWidget {
  const KpBackButton({super.key, required this.onTap, this.label = 'Back'});
  final VoidCallback? onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: const SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: CustomPaint(size: Size.square(26), painter: _ChevronPainter()),
          ),
        ),
      ),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    canvas.drawPath(
      Path()
        ..moveTo(15, 5)
        ..relativeLineTo(-7, 7)
        ..relativeLineTo(7, 7),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = AdColors.ink,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter old) => false;
}

/// A stroke icon drawn in a 24 × 24 box.
class _Stroke24 extends CustomPainter {
  const _Stroke24(this.path, this.color, {this.width = 2.2});
  final Path Function() path;
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    canvas.drawPath(
      path(),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_Stroke24 old) => old.color != color;
}

/// A pencil: change this.
class PencilMark extends StatelessWidget {
  const PencilMark({super.key, this.size = 16, this.color = AdColors.vermilion});
  final double size;
  final Color color;

  static Path _path() => Path()
    ..moveTo(4, 20)
    ..lineTo(4.6, 16.2)
    ..lineTo(15.8, 5)
    ..quadraticBezierTo(17.4, 3.4, 19, 5)
    ..quadraticBezierTo(20.6, 6.6, 19, 8.2)
    ..lineTo(7.8, 19.4)
    ..close()
    ..moveTo(14, 6.8)
    ..lineTo(17.2, 10);

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size.square(size), painter: _Stroke24(_path, color)),
  );
}

/// Two arrows chasing round: send again.
class RefreshMark extends StatelessWidget {
  const RefreshMark({super.key, this.size = 22, this.color = AdColors.ink});
  final double size;
  final Color color;

  static Path _path() => Path()
    ..moveTo(19.5, 12)
    ..arcToPoint(const Offset(6.4, 17.3), radius: const Radius.circular(7.5))
    ..moveTo(4.5, 12)
    ..arcToPoint(const Offset(17.6, 6.7), radius: const Radius.circular(7.5))
    ..moveTo(17.8, 3.2)
    ..lineTo(17.6, 6.7)
    ..lineTo(14.1, 6.6)
    ..moveTo(6.2, 20.8)
    ..lineTo(6.4, 17.3)
    ..lineTo(9.9, 17.4);

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size.square(size), painter: _Stroke24(_path, color)),
  );
}

/// A phone: check the number.
class PhoneMark extends StatelessWidget {
  const PhoneMark({super.key, this.size = 22, this.color = AdColors.ink});
  final double size;
  final Color color;

  static Path _path() => Path()
    ..addRRect(RRect.fromLTRBR(7, 2.5, 17, 21.5, const Radius.circular(3)))
    ..moveTo(10.5, 18.2)
    ..lineTo(13.5, 18.2);

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size.square(size), painter: _Stroke24(_path, color)),
  );
}

/// A small chevron pointing on (end of a row).
class ChevronMark extends StatelessWidget {
  const ChevronMark({super.key, this.size = 18, this.color = AdColors.muted});
  final double size;
  final Color color;

  static Path _path() => Path()
    ..moveTo(9, 5)
    ..lineTo(16, 12)
    ..lineTo(9, 19);

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size.square(size), painter: _Stroke24(_path, color, width: 2.4)),
  );
}
