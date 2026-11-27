import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Material, MaterialType, TextField, InputDecoration;

import '../../core/theme/tokens.dart';
import '../../shared/widgets/hold_scroll.dart';

/// The pieces of About you (GS3 · G7). Reference: docs/design/kalighat-pop/G05AboutYou/ (a reference, not a spec).

const _quick = Duration(milliseconds: 180);
const _instant = Duration(microseconds: 1);

/// What the a says: a white bubble with an ink outline whose tail points right, at the a. [highlight] (a name) is
/// vermilion. It pops out of its tail when [shown] turns on and folds back into it when off. Decorative: what it says
/// is already on the screen, so screen readers skip it.
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({
    super.key,
    required this.prefix,
    this.highlight = '',
    this.suffix = '',
    this.shown = true,
    this.compact = false,
    this.maxLines = 2,
  });

  final String prefix;
  final String highlight;
  final String suffix;
  final bool shown;
  final bool compact;
  final int maxLines;

  static const tail = 11.0;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final style = KpType.bubble(compact: compact);
    final text = Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: prefix),
          if (highlight.isNotEmpty)
            TextSpan(
              text: highlight,
              style: style.copyWith(color: AdColors.vermilion),
            ),
          if (suffix.isNotEmpty) TextSpan(text: suffix),
        ],
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
    return ExcludeSemantics(
      child: AnimatedOpacity(
        opacity: shown ? 1 : 0,
        duration: reduced ? _instant : (shown ? const Duration(milliseconds: 120) : _quick),
        child: AnimatedScale(
          scale: shown ? 1 : .55,
          alignment: Alignment.centerRight,
          duration: reduced ? _instant : (shown ? const Duration(milliseconds: 380) : _quick),
          curve: shown ? const Cubic(.3, 1.4, .5, 1) : Curves.easeIn,
          child: CustomPaint(
            painter: const _BubblePainter(),
            child: AnimatedSize(
              duration: reduced ? _instant : _quick,
              curve: Curves.easeOutCubic,
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 12 : 15,
                  compact ? 7 : 9,
                  (compact ? 12 : 15) + tail,
                  compact ? 8 : 10,
                ),
                child: text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  const _BubblePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width - SpeechBubble.tail, h = size.height;
    final r = math.min(16.0, h / 2 - 7);
    final mid = h / 2;
    final path = Path()
      ..moveTo(r, 1)
      ..lineTo(w - r, 1)
      ..arcToPoint(Offset(w - 1, r), radius: Radius.circular(r - 1))
      ..lineTo(w - 1, mid - 6)
      ..lineTo(w + SpeechBubble.tail - 1, mid + 4)
      ..lineTo(w - 1, mid + 6)
      ..lineTo(w - 1, h - r)
      ..arcToPoint(Offset(w - r, h - 1), radius: Radius.circular(r - 1))
      ..lineTo(r, h - 1)
      ..arcToPoint(Offset(1, h - r), radius: Radius.circular(r - 1))
      ..lineTo(1, r)
      ..arcToPoint(Offset(r, 1), radius: Radius.circular(r - 1))
      ..close();
    canvas.drawPath(path, Paint()..color = AdColors.white);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.miter
        ..color = AdColors.ink,
    );
  }

  @override
  bool shouldRepaint(_BubblePainter old) => false;
}

/// A name field: the label sits inside the box above what you type, so a short phone with the keyboard open still has
/// room for both names and the button (GI-63). Focus: an ink outline and a soft vermilion ring; something that can't be
/// a name: a vermilion outline.
class NameField extends StatefulWidget {
  const NameField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.placeholder,
    required this.autofill,
    this.aside,
    this.bad = false,
    this.compact = false,
    this.action = TextInputAction.next,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String placeholder;
  final String autofill;

  /// A quiet word after the label ("optional").
  final String? aside;
  final bool bad;
  final bool compact;
  final TextInputAction action;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<NameField> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_changed);
  }

  @override
  void didUpdateWidget(NameField old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      old.focusNode.removeListener(_changed);
      widget.focusNode.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final focus = widget.focusNode.hasFocus;
    final (border, width) = widget.bad
        ? (AdColors.vermilion, 2.0)
        : focus
        ? (AdColors.ink, 2.0)
        : (AdColors.fieldBorder, 1.5);
    final ring = focus || widget.bad;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.focusNode.requestFocus,
      child: AnimatedContainer(
        duration: reduced ? _instant : _quick,
        constraints: BoxConstraints(minHeight: widget.compact ? 58 : 64),
        padding: EdgeInsets.fromLTRB(18, widget.compact ? 7 : 9, 16, widget.compact ? 6 : 8),
        decoration: BoxDecoration(
          color: AdColors.white,
          borderRadius: const BorderRadius.all(Radius.circular(18)),
          border: Border.all(color: border, width: width),
          boxShadow: [BoxShadow(color: ring ? AdColors.ring : AdColors.ring.withValues(alpha: 0), spreadRadius: 4)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ExcludeSemantics(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: widget.label, style: KpType.label),
                    if (widget.aside != null) TextSpan(text: '  ·  ${widget.aside}', style: KpType.labelAside),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 2),
            HoldScroll(
              hold: true,
              child: Semantics(
                label: widget.aside == null ? widget.label : '${widget.label}, ${widget.aside}',
                child: Material(
                  type: MaterialType.transparency,
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: widget.action,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: [widget.autofill],
                    inputFormatters: [LengthLimitingTextInputFormatter(40)],
                    style: KpType.nameInput,
                    cursorColor: AdColors.vermilion,
                    cursorWidth: 2,
                    cursorRadius: const Radius.circular(1),
                    decoration: InputDecoration.collapsed(
                      hintText: widget.placeholder,
                      hintStyle: KpType.namePlaceholder,
                    ),
                    onChanged: widget.onChanged,
                    onSubmitted: widget.onSubmitted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where you are in About you: a done step is a short vermilion dash, this one a long ink dash, the next ones quiet.
class StepDots extends StatelessWidget {
  const StepDots({super.key, required this.at, this.count = 3, this.allDone = false});

  /// 0-based.
  final int at;
  final int count;
  final bool allDone;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: allDone ? 'All $count steps done' : 'Step ${at + 1} of $count',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            AnimatedContainer(
              duration: reduced ? _instant : const Duration(milliseconds: 320),
              curve: Curves.easeInOutCubic,
              width: !allDone && i == at ? 28 : 10,
              height: 6,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(3)),
                color: allDone || i < at
                    ? AdColors.vermilion
                    : i == at
                    ? AdColors.ink
                    : AdColors.fieldBorder,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Answers to pick one of. The chosen one turns ink and gets a Kalighat dot border, painted round it in one quick
/// sweep, and its radio dot pops in.
class ChoiceList<T> extends StatelessWidget {
  const ChoiceList({
    super.key,
    required this.label,
    required this.choices,
    required this.selected,
    required this.onSelect,
    this.compact = false,
  });

  final String label;
  final List<(T, String)> choices;
  final T? selected;
  final ValueChanged<T> onSelect;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < choices.length; i++) ...[
            if (i > 0) SizedBox(height: compact ? 8 : 10),
            _Choice(
              text: choices[i].$2,
              on: choices[i].$1 == selected,
              compact: compact,
              onTap: () => onSelect(choices[i].$1),
            ),
          ],
        ],
      ),
    );
  }
}

class _Choice extends StatefulWidget {
  const _Choice({required this.text, required this.on, required this.compact, required this.onTap});
  final String text;
  final bool on;
  final bool compact;
  final VoidCallback onTap;

  @override
  State<_Choice> createState() => _ChoiceState();
}

class _ChoiceState extends State<_Choice> with SingleTickerProviderStateMixin {
  late final _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
    value: widget.on ? 1 : 0,
  );
  bool _down = false;

  @override
  void didUpdateWidget(_Choice old) {
    super.didUpdateWidget(old);
    if (widget.on && !old.on) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _sweep.value = 1;
      } else {
        _sweep.forward(from: 0);
      }
    } else if (!widget.on && old.on) {
      _sweep.value = 0;
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final on = widget.on;
    final d = reduced ? _instant : _quick;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: on,
      button: true,
      label: widget.text,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        child: AnimatedScale(
          scale: _down ? .985 : 1,
          duration: const Duration(milliseconds: 110),
          child: AnimatedContainer(
            duration: d,
            constraints: BoxConstraints(minHeight: widget.compact ? 56 : 62),
            decoration: BoxDecoration(
              color: on ? AdColors.ink : AdColors.white,
              borderRadius: const BorderRadius.all(Radius.circular(18)),
              border: Border.all(color: on ? AdColors.ink : AdColors.fieldBorder, width: 1.5),
            ),
            child: CustomPaint(
              foregroundPainter: _DotBorder(_sweep),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: d,
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: on ? AdColors.paper : AdColors.placeholder, width: 2),
                      ),
                      child: AnimatedScale(
                        scale: on ? 1 : 0,
                        duration: reduced ? _instant : const Duration(milliseconds: 300),
                        curve: on ? Curves.easeOutBack : Curves.easeIn,
                        child: const SizedBox.square(
                          dimension: 10,
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: AdColors.paper, shape: BoxShape.circle),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: AnimatedDefaultTextStyle(
                        duration: d,
                        style: KpType.choice.copyWith(color: on ? AdColors.paper : AdColors.ink),
                        child: Text(widget.text),
                      ),
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

/// The Kalighat painters' white dot border, inside the edge of a chosen card, painted round from the left in one
/// sweep as [sweep] runs 0 → 1.
class _DotBorder extends CustomPainter {
  _DotBorder(this.sweep) : super(repaint: sweep);
  final Animation<double> sweep;

  @override
  void paint(Canvas canvas, Size size) {
    final v = sweep.value;
    if (v <= 0) return;
    final rect = (Offset.zero & size).deflate(6);
    final path = Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)));
    final metric = path.computeMetrics().first;
    const gap = 9.0;
    final n = (metric.length / gap).floor();
    final step = metric.length / n;
    // start at the middle of the left edge, so the sweep begins beside the radio dot
    final start = metric.length - (rect.height / 2 - 12) - (math.pi * 12 / 2);
    final paint = Paint()..color = AdColors.white.withValues(alpha: .85);
    for (var i = 0; i < n; i++) {
      final at = i / n;
      final show = ((v * 1.25 - at) / .25).clamp(0.0, 1.0);
      if (show <= 0) continue;
      final p = metric.getTangentForOffset((start + i * step) % metric.length)!.position;
      canvas.drawCircle(p, 1.5 * show, paint);
    }
  }

  @override
  bool shouldRepaint(_DotBorder old) => false;
}

/// A number whose digits roll when it changes: up when it grows, down when it shrinks.
class RollingNumber extends StatelessWidget {
  const RollingNumber({super.key, required this.value, required this.style, this.up = true});
  final int value;
  final TextStyle style;
  final bool up;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final digits = '$value';
    final s = style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    return ClipRect(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < digits.length; i++)
            AnimatedSwitcher(
              key: ValueKey(digits.length - i),
              duration: reduced ? _instant : const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (current, previous) =>
                  Stack(alignment: Alignment.center, children: [...previous, ?current]),
              transitionBuilder: (child, animation) {
                final incoming = child.key == ValueKey('${digits[i]}$i');
                final from = Offset(0, (incoming ? 1 : -1) * (up ? .7 : -.7));
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(begin: from, end: Offset.zero).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Text(digits[i], key: ValueKey('${digits[i]}$i'), style: s),
            ),
        ],
      ),
    );
  }
}

/// An underlined way to answer differently ("Only know your age?"), with a 48 px touch area.
class TextLinkButton extends StatelessWidget {
  const TextLinkButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: 1,
              child: Text(label, style: KpType.textLink),
            ),
          ),
        ),
      ),
    );
  }
}

/// A round "i": a note that explains.
class InfoMark extends StatelessWidget {
  const InfoMark({super.key, this.size = 22, this.color = AdColors.ink});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size.square(size), painter: _InfoPainter(color)),
  );
}

class _InfoPainter extends CustomPainter {
  const _InfoPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawCircle(const Offset(12, 12), 10, stroke..strokeWidth = 2);
    canvas.drawLine(const Offset(12, 10.5), const Offset(12, 16.5), stroke..strokeWidth = 2.2);
    canvas.drawCircle(const Offset(12, 7.3), 1.4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_InfoPainter old) => old.color != color;
}

/// A small padlock: saved for good.
class LockMark extends StatelessWidget {
  const LockMark({super.key, this.size = 16, this.color = AdColors.muted});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size.square(size), painter: _LockPainter(color)),
  );
}

class _LockPainter extends CustomPainter {
  const _LockPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    canvas.drawRRect(RRect.fromLTRBR(5, 10.5, 19, 21, const Radius.circular(3)), stroke);
    canvas.drawPath(
      Path()
        ..moveTo(8.5, 10.5)
        ..lineTo(8.5, 7.5)
        ..arcToPoint(const Offset(15.5, 7.5), radius: const Radius.circular(3.5))
        ..lineTo(15.5, 10.5),
      stroke,
    );
  }

  @override
  bool shouldRepaint(_LockPainter old) => old.color != color;
}

/// A speech mark with a heart: someone to talk to (Childline).
class TalkMark extends StatelessWidget {
  const TalkMark({super.key, this.size = 24, this.color = AdColors.ink});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size.square(size), painter: _TalkPainter(color)),
  );
}

class _TalkPainter extends CustomPainter {
  const _TalkPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawPath(
      Path()
        ..moveTo(7, 4)
        ..lineTo(17, 4)
        ..arcToPoint(const Offset(21, 8), radius: const Radius.circular(4))
        ..lineTo(21, 13)
        ..arcToPoint(const Offset(17, 17), radius: const Radius.circular(4))
        ..lineTo(11, 17)
        ..lineTo(6.5, 20.5)
        ..lineTo(7, 17)
        ..arcToPoint(const Offset(3, 13), radius: const Radius.circular(4))
        ..lineTo(3, 8)
        ..arcToPoint(const Offset(7, 4), radius: const Radius.circular(4))
        ..close(),
      stroke,
    );
    canvas.drawPath(
      Path()
        ..moveTo(12, 13.6)
        ..cubicTo(8.4, 11.4, 8.6, 8, 10.6, 8)
        ..cubicTo(11.4, 8, 12, 8.6, 12, 9.2)
        ..cubicTo(12, 8.6, 12.6, 8, 13.4, 8)
        ..cubicTo(15.4, 8, 15.6, 11.4, 12, 13.6)
        ..close(),
      Paint()..color = AdColors.vermilion,
    );
  }

  @override
  bool shouldRepaint(_TalkPainter old) => old.color != color;
}

/// A minus or a plus, drawn.
class PlusMinusMark extends StatelessWidget {
  const PlusMinusMark({super.key, required this.plus, this.size = 26, this.color = AdColors.ink});
  final bool plus;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size.square(size), painter: _PlusMinusPainter(plus, color)),
  );
}

class _PlusMinusPainter extends CustomPainter {
  const _PlusMinusPainter(this.plus, this.color);
  final bool plus;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawLine(const Offset(5, 12), const Offset(19, 12), p);
    if (plus) canvas.drawLine(const Offset(12, 5), const Offset(12, 19), p);
  }

  @override
  bool shouldRepaint(_PlusMinusPainter old) => old.plus != plus || old.color != color;
}
