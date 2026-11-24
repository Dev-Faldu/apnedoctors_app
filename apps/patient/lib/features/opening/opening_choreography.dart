import 'dart:ui';

import '../../core/brand/living_a.dart';
import '../../core/motion/keyframes.dart';
import 'opening_spec.g.dart';

/// Where the a must land in the Welcome doorway, in device pixels.
class DoorwayTarget {
  const DoorwayTarget({required this.bowl, required this.scale});

  /// Centre of the a's bowl.
  final Offset bowl;

  /// Scale of the a (1.05 at the board's full-size doorway).
  final double scale;
}

/// The opening's motion, resolved for one screen size.
///
/// Everything happens in the board's 390 x 844 space, centred on the device: board point (195, 422)
/// sits at the screen centre. The native splash shows the a at scale 1 with its bounds centred on
/// the screen, so the app's first frame starts there (the board starts from the home-screen icon,
/// which on a phone the OS animates for us), then follows the board's tracks exactly.
class OpeningChoreography {
  OpeningChoreography({required this.screen, DoorwayTarget? doorway}) {
    boardOffset = Offset((screen.width - OpeningSpec.boardW) / 2, screen.height / 2 - OpeningSpec.boardH / 2);
    final target = doorway == null ? const Offset(OpeningSpec.welBx, OpeningSpec.welBy) : doorway.bowl - boardOffset;
    welScale = doorway?.scale ?? OpeningSpec.welS;
    welBy = target.dy;
    push = (OpeningSpec.midBy - welBy).clamp(0.0, double.infinity);
    aX = OpeningTracks.aX.withValues({
      0: [nativeBowl.dx],
      5: [target.dx],
      6: [target.dx],
    });
    aY = OpeningTracks.aY.withValues({
      0: [nativeBowl.dy],
    });
    aScale = OpeningTracks.aScale.withValues({
      0: [nativeScale],
      5: [welScale],
      6: [welScale],
    });
    // the board takes min(push, offset) at each spring sample, then interpolates linearly
    _hero = Keyframes(
      dim: 1,
      offsets: OpeningSpec.riseOffsets,
      values: [for (final v in OpeningSpec.riseValues) v < push ? v : push],
      curves: List.filled(OpeningSpec.riseOffsets.length, null),
    );
  }

  late final Keyframes _hero;

  final Size screen;
  late final Offset boardOffset;
  late final double welScale;
  late final double welBy;

  /// How far the doorway waits below its place before the headline pushes it up (px).
  late final double push;

  late final Keyframes aX, aY, aScale;

  /// The native splash's a: scale 1, bounds centred on the screen (board centre 195, 422).
  static const nativeScale = 1.0;
  static final Offset nativeBowl = Offset(
    OpeningSpec.boardW / 2 - AShape.bounds.center.dx * nativeScale,
    OpeningSpec.boardH / 2 - AShape.bounds.center.dy * nativeScale,
  );

  /// When the hand-off has settled and Welcome is fully alive.
  static const settled = OpeningSpec.arch + 2.5;

  double p(double t) => (t / OpeningSpec.duration).clamp(0.0, 1.0);

  /// The overlay a's transform in board space at [t].
  ({Offset bowl, double scale}) aPose(double t) {
    final q = p(t);
    return (bowl: Offset(aX.at(q), aY.at(q)), scale: aScale.at(q));
  }

  /// The overlay a's face at [t].
  AFace aFace(double t) {
    final q = p(t);
    return AFace(
      open: OpeningTracks.open.at(q),
      happy: OpeningTracks.happy.at(q),
      blush: OpeningTracks.blush.at(q),
      gaze: Offset(OpeningTracks.gaze.at(q, 0), OpeningTracks.gaze.at(q, 1)),
      lid: OpeningTracks.lid.at(q),
      blushStyle: BlushStyle.wash,
      happyLift: 14,
    );
  }

  /// The a's little body moments (wake pop, inhale, hop, squash): translate(pre) scale translate(post)
  /// around the bottom of the bowl.
  ({double pre, double sx, double sy, double post}) pop(double t) {
    final q = p(t);
    final k = OpeningTracks.pop;
    return (pre: k.at(q, 0), sx: k.at(q, 1), sy: k.at(q, 2), post: k.at(q, 3));
  }

  /// Overlay a visibility: it hands over to Welcome's own a at [OpeningSpec.swap].
  double aOpacity(double t) => _hide.lerp(t, 1, 0)!;
  static const _hide = CssAnim(.01, delay: OpeningSpec.swap, curve: cssLinear);

  /// Welcome's hero offset at [t]: waits at [push] until the rising headline reaches it.
  double heroOffset(double t) {
    final local = (t - OpeningSpec.handRise) / OpeningSpec.riseDuration;
    return _hero.at(local.clamp(0.0, 1.0));
  }

  /// A rising Welcome block's offset at [t] (CSS keyframes, linear between spring samples).
  static double riseOffset(double t, double delay) {
    final local = (t - delay) / OpeningSpec.riseDuration;
    return _rise.at(local.clamp(0.0, 1.0));
  }

  static final _rise = Keyframes(
    dim: 1,
    offsets: OpeningSpec.riseOffsets,
    values: OpeningSpec.riseValues,
    curves: List.filled(OpeningSpec.riseOffsets.length, null),
  );
}
