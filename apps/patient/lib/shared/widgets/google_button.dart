import 'package:flutter/widgets.dart';

import '../../core/theme/tokens.dart';

/// "Continue with Google", drawn to the Get started board (G03 `.btn.google`): a white pill with a quiet outline,
/// Google's own four-colour "G", the label in the app's type. Same height as [PrimaryButton] so the two sit together.
/// Off (offline, while a code is sending): paper-grey, the "G" greyed out.
class GoogleButton extends StatelessWidget {
  const GoogleButton({super.key, required this.onPressed, this.loading = false, this.label = 'Continue with Google'});

  final VoidCallback? onPressed;
  final bool loading;
  final String label;

  static const _grey = ColorFilter.matrix([
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final off = onPressed == null;
    Widget g = const SizedBox(width: 20, height: 20, child: CustomPaint(painter: GoogleG()));
    if (off) {
      g = Opacity(
        opacity: .45,
        child: ColorFiltered(colorFilter: _grey, child: g),
      );
    }
    return Semantics(
      button: true,
      enabled: enabled,
      label: loading ? '$label, working' : label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onPressed : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: loading ? .6 : 1,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: off ? AdColors.lockedFill : AdColors.white,
              borderRadius: const BorderRadius.all(Radius.circular(28)),
              border: Border.all(color: off ? AdColors.lockedBorder : AdColors.fieldBorder, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                g,
                const SizedBox(width: 12),
                Flexible(
                  // longestLine: when large text wraps the label, the "G" stays beside the words, not at the far edge
                  child: Text(
                    label,
                    style: KpType.google.copyWith(color: off ? AdColors.muted : AdColors.ink),
                    textAlign: TextAlign.center,
                    textWidthBasis: TextWidthBasis.longestLine,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Google's "G" mark (from Google's sign-in branding assets), drawn from its 48 × 48 paths.
class GoogleG extends CustomPainter {
  const GoogleG();

  static final _red = Path()
    ..moveTo(24, 9.5)
    ..cubicTo(27.54, 9.5, 30.71, 10.72, 33.21, 13.1)
    ..lineTo(40.06, 6.25)
    ..cubicTo(35.9, 2.38, 30.47, 0, 24, 0)
    ..cubicTo(14.62, 0, 6.51, 5.38, 2.56, 13.22)
    ..lineTo(10.54, 19.41)
    ..cubicTo(12.43, 13.72, 17.74, 9.5, 24, 9.5)
    ..close();
  static final _blue = Path()
    ..moveTo(46.98, 24.55)
    ..cubicTo(46.98, 22.98, 46.83, 21.46, 46.6, 20)
    ..lineTo(24, 20)
    ..lineTo(24, 29.02)
    ..lineTo(36.94, 29.02)
    ..cubicTo(36.36, 31.98, 34.68, 34.5, 32.16, 36.2)
    ..lineTo(39.89, 42.2)
    ..cubicTo(44.4, 38.02, 46.98, 31.84, 46.98, 24.55)
    ..close();
  static final _yellow = Path()
    ..moveTo(10.53, 28.59)
    ..cubicTo(10.05, 27.14, 9.77, 25.6, 9.77, 24)
    ..cubicTo(9.77, 22.4, 10.04, 20.86, 10.53, 19.41)
    ..lineTo(2.55, 13.22)
    ..cubicTo(0.92, 16.46, 0, 20.12, 0, 24)
    ..cubicTo(0, 27.88, 0.92, 31.54, 2.56, 34.78)
    ..lineTo(10.53, 28.59)
    ..close();
  static final _green = Path()
    ..moveTo(24, 48)
    ..cubicTo(30.48, 48, 35.93, 45.87, 39.89, 42.19)
    ..lineTo(32.16, 36.19)
    ..cubicTo(30.01, 37.64, 27.24, 38.49, 24, 38.49)
    ..cubicTo(17.74, 38.49, 12.43, 34.27, 10.53, 28.58)
    ..lineTo(2.55, 34.77)
    ..cubicTo(6.51, 42.62, 14.62, 48, 24, 48)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 48);
    canvas.drawPath(_red, Paint()..color = GoogleBrand.red);
    canvas.drawPath(_blue, Paint()..color = GoogleBrand.blue);
    canvas.drawPath(_yellow, Paint()..color = GoogleBrand.yellow);
    canvas.drawPath(_green, Paint()..color = GoogleBrand.green);
  }

  @override
  bool shouldRepaint(GoogleG old) => false;
}
