import '../opening/opening_spec.g.dart';

/// When each part of Welcome comes alive (s on the screen's clock).
///
/// [handoff]: Welcome is mounted under the splash from its first frame and brought in by the
/// hand-off (N00Splash). [standalone]: Welcome opens on its own (N01Welcome).
class WelcomeTimings {
  const WelcomeTimings._({
    required this.fromSplash,
    required this.band,
    required this.shade,
    required this.inside,
    required this.shadow,
    required this.dots,
    required this.finial,
    required this.toran,
    required this.face,
    required this.lids,
    required this.say,
    required this.shine,
    required this.aIn,
    required this.peek,
    required this.glow,
    required this.bar,
    required this.rise,
    required this.riseLede,
    required this.riseOnline,
    required this.riseActions,
  });

  final bool fromSplash;
  final double band, shade, inside, shadow, dots, finial, toran, face, lids, say, shine;

  /// The doorway's a appears (standalone: steps in; hand-off: takes over from the splash's a).
  final double aIn;

  /// Hand-off only: the a glances down at the words pushing it up.
  final double peek;

  final double glow, bar;
  final double rise, riseLede, riseOnline, riseActions;

  /// The settled moment: everything has arrived and only the idle life continues.
  double get settled => fromSplash ? OpeningSpec.arch + 2.5 : 2.6;

  static const standalone = WelcomeTimings._(
    fromSplash: false,
    band: .15,
    shade: .2,
    inside: .5,
    shadow: 1,
    dots: 1.1,
    finial: 1.05,
    toran: 1.2,
    face: 1.6,
    lids: 2,
    say: 1.75,
    shine: 2,
    aIn: .7,
    peek: -1,
    glow: 0,
    bar: 0,
    rise: .85,
    riseLede: 1,
    riseOnline: 1.2,
    riseActions: 1.4,
  );

  static const handoff = WelcomeTimings._(
    fromSplash: true,
    band: OpeningSpec.handBand,
    shade: OpeningSpec.handShade,
    inside: OpeningSpec.handInside,
    shadow: OpeningSpec.handShadow,
    dots: OpeningSpec.handDots,
    finial: OpeningSpec.handFinial,
    toran: OpeningSpec.handToran,
    face: OpeningSpec.handFace,
    lids: OpeningSpec.handLids,
    say: OpeningSpec.handSay,
    shine: OpeningSpec.handShine,
    aIn: OpeningSpec.handAIn,
    peek: OpeningSpec.handPeek,
    glow: OpeningSpec.handGlow,
    bar: OpeningSpec.handBar,
    rise: OpeningSpec.handRise,
    riseLede: OpeningSpec.handRiseLede,
    riseOnline: OpeningSpec.handRiseOnline,
    riseActions: OpeningSpec.handRiseActions,
  );
}
