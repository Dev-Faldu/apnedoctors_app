import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../core/brand/lockup.dart';
import '../../core/motion/keyframes.dart';
import '../../core/theme/css_paragraph.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/primary_button.dart';
import '../opening/opening_choreography.dart';
import 'doctors_online.dart';
import 'doorway_painter.dart';
import 'welcome_timings.dart';

/// Welcome (N01Welcome): top bar, the painted doorway with the living a, the promise, and the two
/// ways in.
///
/// Every moving part reads one clock, [time] (s), so the screen can be brought in by the splash's
/// hand-off ([WelcomeTimings.handoff]) or open on its own ([WelcomeTimings.standalone]).
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({
    super.key,
    required this.time,
    this.timings = WelcomeTimings.standalone,
    this.reduced = false,
    this.heroOffset,
    this.doctorsOnline,
    this.onGetStarted,
    this.onSignIn,
    this.onForDoctors,
    this.heroKey,
  });

  final ValueListenable<double> time;
  final WelcomeTimings timings;

  /// Reduced motion: the settled frame, no idle loops.
  final bool reduced;

  /// Hand-off only: how far the doorway sits below its place at time t.
  final double Function(double t)? heroOffset;

  /// Real doctors online. Null hides the chip.
  final DoctorsOnline? doctorsOnline;

  final VoidCallback? onGetStarted;
  final VoidCallback? onSignIn;
  final VoidCallback? onForDoctors;

  /// Key on the hero box (untransformed), so the opening can find where the doorway's a stands.
  final GlobalKey? heroKey;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _bubble = TextPainter(textDirection: TextDirection.ltr);

  @override
  void dispose() {
    _bubble.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final w = widget.timings;
    final t = widget.time;
    final reduced = widget.reduced;
    _bubble
      ..text = TextSpan(text: 'namaste!', style: AdType.bubble)
      ..textScaler = TextScaler.noScaling
      ..layout();

    return LayoutBuilder(
      builder: (context, box) {
        // the board's short-screen rule: @media (max-height: 700px)
        final compact = box.maxHeight <= 700;
        final top = math.max(16.0, mq.padding.top);
        final bottom = math.max(26.0, mq.padding.bottom);
        final scaler = mq.textScaler;

        Widget rise(Widget child, double delay) {
          if (reduced) return child;
          return _Rise(time: t, delay: delay, fromSplash: w.fromSplash, child: child);
        }

        final hero = ConstrainedBox(
          key: widget.heroKey,
          constraints: const BoxConstraints(minHeight: 140),
          child: _HeroMotion(
            time: t,
            offset: reduced ? null : widget.heroOffset,
            child: Semantics(
              label: 'The ApneDoctors a stands in a painted Indian doorway and greets you with a namaste',
              image: true,
              child: CustomPaint(
                painter: DoorwayPainter(time: t, timings: w, reduced: reduced, compact: compact, bubbleText: _bubble),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );

        final copy = Padding(
          padding: const EdgeInsets.symmetric(horizontal: AdSpace.side),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              rise(
                Semantics(
                  header: true,
                  child: Text(
                    'doctors who\nfeel like\nfamily.',
                    style: AdType.display(compact: compact),
                    textScaler: scaler.clamp(maxScaleFactor: 1.3),
                  ),
                ),
                w.rise,
              ),
              const SizedBox(height: 12),
              rise(
                CssParagraph(
                  'See a doctor in minutes. Medicines and tests at home. The whole family’s health in one place.',
                  style: AdType.lede(compact: compact),
                ),
                w.riseLede,
              ),
              // The live count comes and goes smoothly once Welcome is on screen; before that (and
              // with reduced motion) it simply is there or not.
              _ChipSlot(
                animate: !reduced && !(w.fromSplash && t.value < w.settled),
                child: widget.doctorsOnline != null && widget.doctorsOnline!.count > 0
                    ? Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: rise(
                          DoctorsOnlineChip(online: widget.doctorsOnline!, time: t, reduced: reduced),
                          w.riseOnline,
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        );

        final actions = rise(
          Padding(
            padding: const EdgeInsets.fromLTRB(AdSpace.side, 18, AdSpace.side, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PrimaryButton(
                  label: 'Get started',
                  // Welcome's door always looks open; Get started (GS1) is wired as it is built
                  onPressed: widget.onGetStarted ?? () {},
                  shine: reduced ? null : ShineTiming(time: t, delay: w.shine),
                ),
                const SizedBox(height: 4),
                _TextLink(label: 'I already have an account', onTap: widget.onSignIn),
              ],
            ),
          ),
          w.riseActions,
        );

        final page = SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: top + 44),
                  Expanded(child: hero),
                  copy,
                  actions,
                  // the link's touch area is 48 tall (7 more than the board's 41), taken from this gap
                  SizedBox(height: bottom - 7),
                ],
              ),
            ),
          ),
        );

        final bar = _BarMotion(
          time: t,
          delay: w.bar,
          enabled: w.fromSplash && !reduced,
          child: Padding(
            padding: const EdgeInsets.only(left: AdSpace.side - 1, right: AdSpace.side),
            // labels grow up to 1.5x here; "For doctors" gives way before the brand does
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.5,
              child: Row(
                children: [
                  const Lockup(),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _ForDoctors(onTap: widget.onForDoctors),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        return ColoredBox(
          color: w.fromSplash ? const Color(0x00000000) : AdColors.paper,
          child: Stack(
            children: [
              Positioned.fill(child: page),
              // the bar is 44 tall on the board; its touch row is 48, centred on the same line
              Positioned(left: 0, right: 0, top: top - 2, height: 48, child: bar),
            ],
          ),
        );
      },
    );
  }
}

/// Holds the doctors chip. Changes slide (450 ms) once Welcome is on screen; before that, and with
/// reduced motion, they land on the next frame. (One animator throughout, so the first change after
/// the hand-off slides too. A zero duration would re-layout inside layout, hence one microsecond.)
class _ChipSlot extends StatelessWidget {
  const _ChipSlot({required this.animate, required this.child});
  final bool animate;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: animate ? const Duration(milliseconds: 450) : const Duration(microseconds: 1),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topLeft,
      child: child,
    );
  }
}

/// Rise into place: from the splash, a damped spring from 540 px below (`wl-rise`); on its own,
/// a short fade up from 18 px (`kRise`).
class _Rise extends StatelessWidget {
  const _Rise({required this.time, required this.delay, required this.fromSplash, required this.child});

  final ValueListenable<double> time;
  final double delay;
  final bool fromSplash;
  final Widget child;

  static const _kRise = CssAnim(.5, curve: cssEaseOut);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: time,
      child: child,
      builder: (context, t, child) {
        if (fromSplash) {
          return Transform.translate(offset: Offset(0, OpeningChoreography.riseOffset(t, delay)), child: child);
        }
        final p = CssAnim(_kRise.duration, delay: delay, curve: _kRise.curve).progress(t)!;
        final e = _kRise.curve.transform(p);
        return Opacity(
          opacity: e,
          child: Transform.translate(offset: Offset(0, 18 * (1 - e)), child: child),
        );
      },
    );
  }
}

class _HeroMotion extends StatelessWidget {
  const _HeroMotion({required this.time, required this.offset, required this.child});

  final ValueListenable<double> time;
  final double Function(double t)? offset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final f = offset;
    if (f == null) return child;
    return ValueListenableBuilder<double>(
      valueListenable: time,
      child: child,
      builder: (context, t, child) => Transform.translate(offset: Offset(0, f(t)), child: child),
    );
  }
}

/// The top bar fades down into place after the doorway starts painting (`wl-bar`).
class _BarMotion extends StatelessWidget {
  const _BarMotion({required this.time, required this.delay, required this.enabled, required this.child});

  final ValueListenable<double> time;
  final double delay;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return ValueListenableBuilder<double>(
      valueListenable: time,
      child: child,
      builder: (context, t, child) {
        final a = CssAnim(.5, delay: delay, curve: const Cubic(.2, .8, .2, 1));
        final e = a.curve.transform(a.progress(t)!);
        return IgnorePointer(
          ignoring: e < 1,
          child: Opacity(
            opacity: e.clamp(0.0, 1.0),
            child: Transform.translate(offset: Offset(0, -10 * (1 - e)), child: child),
          ),
        );
      },
    );
  }
}

class _ForDoctors extends StatelessWidget {
  const _ForDoctors({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: 'For doctors',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  'For doctors',
                  style: AdType.link,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                ),
              ),
              const SizedBox(width: 6),
              const CustomPaint(size: Size(18, 18), painter: _Chevron()),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chevron extends CustomPainter {
  const _Chevron();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    canvas.drawPath(
      Path()
        ..moveTo(9, 5)
        ..lineTo(16, 12)
        ..lineTo(9, 19),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = AdColors.ink,
    );
  }

  @override
  bool shouldRepaint(_Chevron old) => false;
}

class _TextLink extends StatelessWidget {
  const _TextLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(label, textAlign: TextAlign.center, style: AdType.linkUnderlined),
          ),
        ),
      ),
    );
  }
}
