import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion/keyframes.dart';
import '../../core/theme/tokens.dart';

/// Real doctors online right now. The chip only appears when this is known and above zero:
/// ApneDoctors never shows a made-up number.
@immutable
class DoctorsOnline {
  const DoctorsOnline({required this.count, this.faces = const []});

  final int count;

  /// Up to three doctors to show on the chip: initials and a tint.
  final List<({String initials, Color tint})> faces;
}

/// Live count of verified doctors online. Null until the backend provides it (no doctor directory
/// exists yet), so the chip stays hidden.
final doctorsOnlineProvider = Provider<DoctorsOnline?>((ref) => null);

/// "14 doctors online now": white pill with doctors' faces and a live green dot.
class DoctorsOnlineChip extends StatelessWidget {
  const DoctorsOnlineChip({super.key, required this.online, required this.time, this.reduced = false});

  final DoctorsOnline online;
  final ValueListenable<double> time;
  final bool reduced;

  @override
  Widget build(BuildContext context) {
    final label = '${online.count} ${online.count == 1 ? 'doctor' : 'doctors'} online now';
    final faces = online.faces.take(3).toList();
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.only(left: 6, right: 14, top: 4, bottom: 4),
        decoration: const BoxDecoration(
          color: AdColors.white,
          borderRadius: BorderRadius.all(Radius.circular(999)),
          boxShadow: [BoxShadow(color: Color(0x0F1A1410), offset: Offset(0, 1))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (faces.isNotEmpty) ...[
              SizedBox(
                width: 32 + 22.0 * (faces.length - 1),
                height: 32,
                child: Stack(
                  children: [
                    for (var i = 0; i < faces.length; i++)
                      Positioned(left: 22.0 * i, top: 0, child: _Face(faces[i].initials, faces[i].tint)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
            ],
            SizedBox(width: 9, height: 9, child: CustomPaint(painter: _LiveDot(time, reduced))),
            const SizedBox(width: 10),
            Flexible(child: Text(label, style: AdType.chip)),
          ],
        ),
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face(this.initials, this.tint);
  final String initials;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: tint,
        shape: BoxShape.circle,
        border: Border.all(color: AdColors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(initials, style: AdType.avatar),
    );
  }
}

/// Green dot with a ring that breathes out (`livePulse`, 2 s).
class _LiveDot extends CustomPainter {
  _LiveDot(this.time, this.reduced) : super(repaint: reduced ? null : time);
  final ValueListenable<double> time;
  final bool reduced;

  static final _ring = Keyframes(
    dim: 2, // spread px, alpha
    offsets: const [0, .6, 1],
    values: const [0, .55, 7, 0, 0, .55],
    curves: const [null, null, null],
  );
  static const _anim = CssAnim(2, infinite: true, curve: cssEaseInOut);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    if (!reduced) {
      final p = _anim.progress(time.value)!;
      final spread = _ring.at(p, 0, _anim.curve);
      final alpha = _ring.at(p, 1, _anim.curve);
      if (alpha > 0 && spread > 0) {
        canvas.drawCircle(c, 4.5 + spread, Paint()..color = AdColors.green.withValues(alpha: alpha.clamp(0, 1)));
      }
    }
    canvas.drawCircle(c, 4.5, Paint()..color = AdColors.green);
  }

  @override
  bool shouldRepaint(_LiveDot old) => old.reduced != reduced || old.time != time;
}

/// Kept for previews and tests that show the chip as the board does.
const boardDoctorsOnline = DoctorsOnline(
  count: 14,
  faces: [
    (initials: 'AR', tint: AdColors.avatarIndigo),
    (initials: 'KM', tint: AdColors.avatarRose),
    (initials: 'SN', tint: AdColors.avatarLeaf),
  ],
);
