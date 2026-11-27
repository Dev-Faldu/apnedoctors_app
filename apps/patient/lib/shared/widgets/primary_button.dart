import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../core/motion/keyframes.dart';
import '../../core/theme/tokens.dart';

/// Which board the button comes from.
enum ButtonSize {
  /// kp.css `.btn`: 56 px, 18 px label, flat. Every screen after Welcome.
  regular,

  /// Welcome's "Get started": 58 px, 19 px label, a soft vermilion shadow.
  hero,
}

/// The fill of an enabled button.
enum ButtonTone {
  /// The one main action (`.btn.primary`).
  vermilion,

  /// Something done or settled (`.btn.done`): ink with paper text.
  ink,

  /// The quieter second choice beside a main one (`.btn.ghost`): an ink outline, ink text.
  outline,
}

/// The one main action on a screen: a vermilion pill.
///
/// - `onPressed: null` → disabled: readable quiet colours, not a faded red.
/// - `loading` → three breathing dots, with [busyLabel] beside them when given ("Sending code"); taps are ignored,
///   so a second tap never sends twice (GI-24).
/// - With large text it grows taller instead of clipping (GI-60).
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.busyLabel,
    this.shine,
    this.size = ButtonSize.regular,
    this.tone = ButtonTone.vermilion,
    this.leading,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final String? busyLabel;

  /// The soft band of light that crosses the button every 3.6 s. Null: no shine.
  final ShineTiming? shine;
  final ButtonSize size;
  final ButtonTone tone;

  /// A small drawn icon before the label.
  final Widget? leading;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

/// When the shine runs: on [time], starting at [delay] (s).
@immutable
class ShineTiming {
  const ShineTiming({required this.time, required this.delay});
  final ValueListenable<double> time;
  final double delay;
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _down = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final on = widget.onPressed != null || widget.loading;
    final hero = widget.size == ButtonSize.hero;
    final height = hero ? 58.0 : 56.0;
    final radius = Radius.circular(height / 2);
    final ink = widget.tone == ButtonTone.ink;
    final outline = widget.tone == ButtonTone.outline;
    final fill = !on
        ? AdColors.disabledFill
        : outline
        ? AdColors.paperClear
        : (ink ? AdColors.ink : AdColors.vermilion);
    final style = switch ((hero, on)) {
      (true, true) => AdType.button,
      (true, false) => AdType.buttonDisabled,
      (false, true) => KpType.button,
      (false, false) => KpType.buttonOff,
    }.copyWith(color: on ? (outline ? AdColors.ink : (ink ? AdColors.paper : AdColors.white)) : AdColors.muted);
    final shine = widget.shine;
    final busy = widget.busyLabel;

    Widget content;
    if (widget.loading) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LoadingDots(reduced: reduced, big: busy == null),
          if (busy != null) ...[
            const SizedBox(width: 12),
            Flexible(
              child: Text(busy, textAlign: TextAlign.center, style: style),
            ),
          ],
        ],
      );
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.leading != null) ...[widget.leading!, const SizedBox(width: 8)],
          Flexible(
            child: Text(widget.label, textAlign: TextAlign.center, style: style),
          ),
        ],
      );
    }

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.loading ? (busy ?? '${widget.label}, working') : widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _enabled ? widget.onPressed : null,
        onTapDown: _enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: _enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: _enabled ? () => setState(() => _down = false) : null,
        child: AnimatedScale(
          scale: _down ? .98 : 1,
          duration: const Duration(milliseconds: 120),
          child: CustomPaint(
            // Welcome: box-shadow 0 10px 24px rgba(200,48,43,.28), a Gaussian with sigma = blur / 2
            painter: hero && on
                ? const _SoftShadow(radius: 29, offset: Offset(0, 10), blur: 24, color: Color(0x47C8302B))
                : null,
            child: Container(
              constraints: BoxConstraints(minHeight: height),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.all(radius),
                border: outline && on ? Border.all(color: AdColors.ink, width: 1.5) : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.all(radius),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), child: content),
                    if (shine != null && on && !reduced && !widget.loading)
                      Positioned.fill(
                        child: _Shine(time: shine.time, delay: shine.delay),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A CSS `box-shadow` painted directly (blur as a Gaussian with sigma = blur / 2).
class _SoftShadow extends CustomPainter {
  const _SoftShadow({required this.radius, required this.offset, required this.blur, required this.color});
  final double radius;
  final Offset offset;
  final double blur;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(offset & size, Radius.circular(radius)),
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur / 2),
    );
  }

  @override
  bool shouldRepaint(_SoftShadow old) => false;
}

/// A soft band of light crossing the button every 3.6 s (`kShine`). Before its first sweep it waits off-button
/// (the board leaves it resting on the button, a CSS fill-mode slip).
class _Shine extends StatelessWidget {
  const _Shine({required this.time, required this.delay});

  final ValueListenable<double> time;
  final double delay;

  static final _x = Keyframes.of(const [(0, -1.4), (.72, -1.4), (1, 3.2)]);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 56,
        height: double.infinity,
        child: ValueListenableBuilder<double>(
          valueListenable: time,
          builder: (context, t, _) {
            final a = CssAnim(3.6, delay: delay, infinite: true, fill: Fill.none, curve: cssEaseInOut);
            final p = a.progress(t) ?? 0;
            final x = _x.at(p, 0, a.curve) * 56;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.translationValues(x, 0, 0)..multiply(Matrix4.skewX(-20 * math.pi / 180)),
              child: const ColoredBox(color: Color(0x47FFFFFF)),
            );
          },
        ),
      ),
    );
  }
}

/// Three dots breathing one after another.
///
/// - beside a label (G03 `.sdots`): 7 px white dots 5 px apart, opacity .2 → 1 → .2 over 1.1 s, .18 s apart;
/// - alone ([big]): the splash's loading dots.
class _LoadingDots extends StatefulWidget {
  const _LoadingDots({required this.reduced, required this.big});
  final bool reduced;
  final bool big;

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _t = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((e) => _t.value = e.inMicroseconds / 1e6);
    if (!widget.reduced) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.big
        ? SizedBox(width: 48, height: 21, child: CustomPaint(painter: _BigDotsPainter(_t, widget.reduced)))
        : SizedBox(width: 31, height: 7, child: CustomPaint(painter: _DotsPainter(_t, widget.reduced)));
  }
}

class _DotsPainter extends CustomPainter {
  _DotsPainter(this.t, this.reduced) : super(repaint: t);
  final ValueListenable<double> t;
  final bool reduced;

  static final _kDot = Keyframes.of(const [(0, .2), (.5, 1), (1, .2)]);

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 3; i++) {
      final anim = CssAnim(1.1, delay: i * .18, infinite: true, fill: Fill.none, curve: cssEaseInOut);
      final op = reduced ? 1.0 : (anim.sample(t.value, _kDot) ?? 1);
      canvas.drawCircle(Offset(3.5 + i * 12, 3.5), 3.5, Paint()..color = AdColors.white.withValues(alpha: op));
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.reduced != reduced;
}

class _BigDotsPainter extends CustomPainter {
  _BigDotsPainter(this.t, this.reduced) : super(repaint: t);
  final ValueListenable<double> t;
  final bool reduced;

  static final _pulse = Keyframes(
    dim: 2,
    offsets: const [0, .5, 1],
    values: const [.35, .8, 1, 1, .35, .8],
    curves: const [null, null, null],
  );

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 3; i++) {
      final anim = CssAnim(1.2, delay: i * .18, infinite: true, curve: cssEaseInOut);
      final p = reduced ? .5 : (anim.progress(t.value) ?? 0);
      final op = _pulse.at(p, 0, anim.curve);
      final s = _pulse.at(p, 1, anim.curve);
      canvas.drawCircle(
        Offset(size.width / 2 + (i - 1) * 16, size.height / 2),
        4 * s,
        Paint()..color = AdColors.paper.withValues(alpha: op),
      );
    }
  }

  @override
  bool shouldRepaint(_BigDotsPainter old) => old.reduced != reduced;
}
