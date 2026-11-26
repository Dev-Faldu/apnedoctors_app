import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Material, MaterialType, TextField, InputDecoration;

import '../../core/motion/keyframes.dart';
import '../../core/theme/css_paragraph.dart';
import '../../core/theme/tokens.dart';
import '../indian_phone.dart';
import 'kp_icons.dart';

/// How the field's box looks.
enum PhoneFieldLook { idle, focus, ok, bad, locked }

/// The mobile number field (GS1, SI1, PR2).
///
/// The number is the hero: a fixed +91, then ten slots in the shape of an Indian mobile (five, a breath, five). An
/// empty slot is a small painted dot, like the dot borders of Kalighat painting; each digit you type drops into its
/// slot and takes the dot's place, and a pasted or autofilled number fills in one slot after another. A tick pops in
/// when the number looks right. Underneath, one real text field does the typing, pasting, autofill and screen
/// reading ("Mobile number, plus 91").
///
/// Typing or pasting any common form (+91, 91, 0, spaces, dashes) lands as ten digits (GI-20, GI-22). A first digit of
/// 0–5 is called out at once (GI-21); another country's number is refused (GI-23).
class PhoneField extends StatefulWidget {
  const PhoneField({
    super.key,
    required this.controller,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.autofocus = false,
    this.locked = false,
    this.validHelp = 'We’ll text a 6-digit code to this number.',
    this.message,
    this.messageIsError = false,
    this.holdScroll = false,
  });

  /// Holds the ten digits as typed (`98765 43210`).
  final TextEditingController controller;

  /// Every change, already parsed.
  final ValueChanged<PhoneParse>? onChanged;
  final ValueChanged<PhoneParse>? onSubmitted;

  final FocusNode? focusNode;
  final bool autofocus;

  /// While a code is being sent, or once it has been: greyed, can't be changed.
  final bool locked;

  /// The help line once the number looks right.
  final String validHelp;

  /// Replaces the help line (a server answer, "code sent"). An empty string hides it.
  final String? message;

  /// [message] is a problem: shown in the error colour with the alert mark.
  final bool messageIsError;

  /// The screen decides what scrolls into view when the keyboard opens (the text field would otherwise scroll itself
  /// into view straight away, before the screen's layout has settled).
  final bool holdScroll;

  @override
  State<PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<PhoneField> with TickerProviderStateMixin {
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  late final AnimationController _nudge = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final Ticker _ticker = createTicker(_tick);
  final _clock = ValueNotifier<double>(0);
  double _elapsedBase = 0;

  /// When each slot's digit landed, and when each slot's dot came back (clock seconds).
  final _born = List<double>.filled(10, -10);
  final _dotBack = List<double>.filled(10, -10);
  double _lastEdit = -10;
  String _shown = '';

  bool _foreign = false;
  PhoneFieldLook? _lastLook;
  String? _reported;

  @override
  void initState() {
    super.initState();
    _shown = _digits;
    _focus.addListener(_focusChanged);
    widget.controller.addListener(_textChanged);
  }

  @override
  void didUpdateWidget(PhoneField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_textChanged);
      widget.controller.addListener(_textChanged);
      _textChanged();
    }
    if (widget.locked != old.locked) _wake();
  }

  @override
  void dispose() {
    _focus.removeListener(_focusChanged);
    widget.controller.removeListener(_textChanged);
    if (widget.focusNode == null) _focus.dispose();
    _nudge.dispose();
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  bool get _reduced => MediaQuery.disableAnimationsOf(context);

  // ---- the clock: runs only while something moves (a digit landing, the caret blinking) ------

  void _tick(Duration e) {
    _clock.value = _elapsedBase + e.inMicroseconds / 1e6;
    final settling = _clock.value - math.max(_lastEdit, _born.reduce(math.max)) < .6;
    if (!settling && !(_focus.hasFocus && !widget.locked)) {
      _elapsedBase = _clock.value;
      _ticker.stop();
    }
  }

  void _wake() {
    if (!mounted || _reduced || _ticker.isActive) return;
    _ticker.start();
  }

  void _focusChanged() {
    setState(() {});
    _wake();
  }

  void _textChanged() {
    final d = _digits;
    if (d != _shown) {
      final now = _clock.value;
      var first = 0;
      while (first < d.length && first < _shown.length && d[first] == _shown[first]) {
        first++;
      }
      for (var i = first; i < d.length && i < 10; i++) {
        _born[i] = now + (i - first) * .035; // a paste fills slot after slot
      }
      for (var i = d.length; i < _shown.length && i < 10; i++) {
        _dotBack[i] = now;
      }
      _shown = d;
      _lastEdit = now;
    }
    setState(() {});
    _wake();
  }

  // ---- what the number is -----------------------------------------------------------------------

  String get _digits => widget.controller.text.replaceAll(RegExp(r'\D'), '');

  PhoneParse get _parse => _foreign ? const PhoneBad(PhoneProblem.notIndian) : parseIndianPhone(widget.controller.text);

  /// Called out as soon as it can't become a mobile number: another country, or a first digit of 0–5.
  bool get _wrong => _foreign || (_digits.isNotEmpty && !RegExp(r'^[6-9]').hasMatch(_digits));

  /// Reports a change once. A foreign paste into an empty field leaves the text empty, so the text field itself
  /// would never report it (GI-23); the formatter reports it here instead.
  void _report() {
    final key = _foreign ? 'foreign' : widget.controller.text;
    if (key == _reported) return;
    _reported = key;
    widget.onChanged?.call(_parse);
  }

  void _foreignPaste(bool foreign) {
    if (foreign == _foreign) return;
    setState(() => _foreign = foreign);
    if (foreign) _report();
  }

  PhoneFieldLook get _look {
    if (widget.locked) return PhoneFieldLook.locked;
    if (_wrong) return PhoneFieldLook.bad;
    if (_parse is PhoneOk) return PhoneFieldLook.ok;
    if (_focus.hasFocus) return PhoneFieldLook.focus;
    return PhoneFieldLook.idle;
  }

  (String, bool) get _help {
    final m = widget.message;
    if (m != null) return (m, widget.messageIsError);
    if (_foreign) return (phoneProblemText(PhoneProblem.notIndian), true);
    if (_wrong) return (phoneStartHint, true);
    if (_parse is PhoneOk) return (widget.validHelp, false);
    return ('', false);
  }

  // ---- large text (GI-60) -----------------------------------------------------------------------

  // around the digits: side padding, borders, +91's gaps and divider, and the tick's room
  static const _chrome = 18.0 + 16 + 2 * 2 + 12 * 2 + 1.5 + 12 + 26;

  /// At very large text the whole number must still fit on one line: the digits grow as far as the field's width
  /// allows. The label and help around the field keep the person's full text size.
  static TextScaler fitScaler(TextScaler scaler, double fieldWidth) {
    final cc = TextPainter(
      text: TextSpan(text: '+91', style: KpType.countryCode),
      textDirection: TextDirection.ltr,
    )..layout();
    final atOne = cc.width + DigitSlots.widthAt(TextScaler.noScaling);
    cc.dispose();
    final fits = (fieldWidth - _chrome) / atOne;
    final size = KpType.digits.fontSize!;
    final asked = scaler.scale(size) / size;
    return asked <= fits ? scaler : TextScaler.linear(fits.clamp(1.0, asked));
  }

  // ---- drawing ----------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final look = _look;
    if (look == PhoneFieldLook.bad && _lastLook != PhoneFieldLook.bad && !_reduced) _nudge.forward(from: 0);
    _lastLook = look;
    final (help, helpBad) = _help;
    final quick = _reduced ? const Duration(microseconds: 1) : const Duration(milliseconds: 180);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, box) {
            final scaler = fitScaler(MediaQuery.textScalerOf(context), box.maxWidth);
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: scaler),
              child: AnimatedBuilder(
                animation: _nudge,
                builder: (context, child) =>
                    Transform.translate(offset: Offset(_nudgeAt(_nudge.value), 0), child: child),
                child: _box(scaler, look),
              ),
            );
          },
        ),
        AnimatedSize(
          duration: quick,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: AnimatedSwitcher(
            duration: quick,
            layoutBuilder: (current, previous) =>
                Stack(alignment: Alignment.topLeft, children: [...previous, ?current]),
            child: help.isEmpty
                ? const SizedBox(key: ValueKey(''), width: double.infinity, height: 8)
                : Padding(
                    key: ValueKey(help),
                    padding: const EdgeInsets.only(top: 10),
                    child: Semantics(
                      liveRegion: true,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (helpBad) ...[
                            const Padding(padding: EdgeInsets.only(top: 2), child: AlertMark(size: 18)),
                            const SizedBox(width: 8),
                          ],
                          Expanded(child: CssParagraph(help, style: helpBad ? KpType.helpBad : KpType.help)),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // gsNudge: 0, -5, 4, -2, 0 px at 0, 25, 50, 75, 100 %
  static final _nudgeFrames = Keyframes.of(const [(0, 0), (.25, -5), (.5, 4), (.75, -2), (1, 0)]);
  double _nudgeAt(double v) => _nudgeFrames.at(v, 0, cssEaseInOut);

  Widget _box(TextScaler scaler, PhoneFieldLook look) {
    final (border, width) = switch (look) {
      PhoneFieldLook.idle => (AdColors.fieldBorder, 1.5),
      PhoneFieldLook.focus || PhoneFieldLook.ok => (AdColors.ink, 2.0),
      PhoneFieldLook.bad => (AdColors.vermilion, 2.0),
      PhoneFieldLook.locked => (AdColors.lockedBorder, 1.5),
    };
    final ring = look == PhoneFieldLook.focus || look == PhoneFieldLook.bad;
    final valid = _parse is PhoneOk && widget.message?.isNotEmpty != true;
    final quick = _reduced ? const Duration(microseconds: 1) : const Duration(milliseconds: 160);
    final slots = DigitSlots(
      clock: _clock,
      digits: _shown.length > 10 ? _shown.substring(0, 10) : _shown,
      born: List.of(_born),
      dotBack: List.of(_dotBack),
      lastEdit: _lastEdit,
      caret: _focus.hasFocus && !widget.locked,
      color: widget.locked ? AdColors.muted : AdColors.ink,
      reduced: _reduced,
      scaler: scaler,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.locked ? null : _focus.requestFocus,
      child: AnimatedContainer(
        duration: quick,
        constraints: BoxConstraints(minHeight: math.max(64, scaler.scale(24) * 1.25 + 30)),
        padding: const EdgeInsets.only(left: 18, right: 16),
        decoration: BoxDecoration(
          color: look == PhoneFieldLook.locked ? AdColors.lockedFill : AdColors.white,
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          border: Border.all(color: border, width: width),
          boxShadow: [BoxShadow(color: ring ? AdColors.ring : AdColors.ring.withValues(alpha: 0), spreadRadius: 4)],
        ),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Text(
                '+91',
                style: KpType.countryCode.copyWith(color: widget.locked ? AdColors.muted : AdColors.ink),
              ),
            ),
            const SizedBox(width: 12),
            Container(width: 1.5, height: 28, color: AdColors.line),
            const SizedBox(width: 12),
            Expanded(
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  ExcludeSemantics(child: slots),
                  // the real input: invisible, but it types, pastes, autofills and speaks
                  Positioned.fill(
                    child: _HoldScroll(
                      hold: widget.holdScroll,
                      child: Opacity(
                        opacity: 0,
                        alwaysIncludeSemantics: true,
                        child: Semantics(
                          label: 'Mobile number, plus 91',
                          child: Material(
                            type: MaterialType.transparency,
                            child: TextField(
                              controller: widget.controller,
                              focusNode: _focus,
                              autofocus: widget.autofocus,
                              readOnly: widget.locked,
                              showCursor: false,
                              enableInteractiveSelection: !widget.locked,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [
                                AutofillHints.telephoneNumberNational,
                                AutofillHints.telephoneNumber,
                              ],
                              inputFormatters: [IndianPhoneFormatter(onForeign: _foreignPaste)],
                              style: KpType.digits.copyWith(color: const Color(0x00000000)),
                              decoration: const InputDecoration.collapsed(hintText: null),
                              onChanged: (_) => _report(),
                              onSubmitted: (_) => widget.onSubmitted?.call(_parse),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox.square(
              dimension: 26,
              child: AnimatedScale(
                scale: valid ? 1 : 0,
                duration: _reduced ? const Duration(microseconds: 1) : const Duration(milliseconds: 320),
                curve: valid ? Curves.easeOutBack : Curves.easeIn,
                child: const TickMark(size: 26),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stops "show me on screen" requests from the text field below it, when the screen manages scrolling itself.
class _HoldScroll extends SingleChildRenderObjectWidget {
  const _HoldScroll({required this.hold, required super.child});
  final bool hold;

  @override
  _RenderHoldScroll createRenderObject(BuildContext context) => _RenderHoldScroll(hold);

  @override
  void updateRenderObject(BuildContext context, _RenderHoldScroll renderObject) => renderObject.hold = hold;
}

class _RenderHoldScroll extends RenderProxyBox {
  _RenderHoldScroll(this.hold);
  bool hold;

  @override
  void showOnScreen({
    RenderObject? descendant,
    Rect? rect,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
  }) {
    if (!hold) super.showOnScreen(descendant: descendant, rect: rect, duration: duration, curve: curve);
  }
}

/// Ten slots for the digits: five, a breath, five. An empty slot shows a painted dot; a typed digit drops in
/// (0.22 s) and takes the dot's place; a deleted digit gives its dot back. The caret (vermilion, blinking) waits in
/// the next slot.
class DigitSlots extends LeafRenderObjectWidget {
  const DigitSlots({
    super.key,
    required this.clock,
    required this.digits,
    required this.born,
    required this.dotBack,
    required this.lastEdit,
    required this.caret,
    required this.color,
    required this.reduced,
    required this.scaler,
  });

  final ValueListenable<double> clock;
  final String digits;
  final List<double> born;
  final List<double> dotBack;
  final double lastEdit;
  final bool caret;
  final Color color;
  final bool reduced;
  final TextScaler scaler;

  /// One slot: the widest digit plus a little air.
  static double slotAt(TextScaler s) {
    var widest = 0.0;
    for (var d = 0; d < 10; d++) {
      final p =
          TextPainter(
              text: TextSpan(text: '$d', style: KpType.digits),
              textDirection: TextDirection.ltr,
            )
            ..textScaler = s
            ..layout();
      widest = math.max(widest, p.width);
      p.dispose();
    }
    return widest + s.scale(2.5);
  }

  /// Ten slots and the breath after the fifth (55% of a slot).
  static double widthAt(TextScaler s) => slotAt(s) * 10.55;

  @override
  RenderDigitSlots createRenderObject(BuildContext context) => RenderDigitSlots(this);

  @override
  void updateRenderObject(BuildContext context, RenderDigitSlots renderObject) => renderObject.config = this;
}

class RenderDigitSlots extends RenderBox {
  RenderDigitSlots(this._config) {
    _measure();
  }

  DigitSlots _config;
  set config(DigitSlots v) {
    final relayout = v.scaler != _config.scaler;
    if (v.clock != _config.clock && attached) {
      _config.clock.removeListener(markNeedsPaint);
      v.clock.addListener(markNeedsPaint);
    }
    final colour = v.color != _config.color;
    _config = v;
    if (relayout || colour) _measure();
    if (relayout) markNeedsLayout();
    markNeedsPaint();
  }

  late double _slot;
  late double _height;
  final _glyphs = <String, TextPainter>{};

  void _measure() {
    _slot = DigitSlots.slotAt(_config.scaler);
    _height = _config.scaler.scale(KpType.digits.fontSize!) * KpType.digits.height!;
    for (final p in _glyphs.values) {
      p.dispose();
    }
    _glyphs.clear();
  }

  TextPainter _glyph(String d) => _glyphs.putIfAbsent(
    d,
    () => TextPainter(
      text: TextSpan(
        text: d,
        style: KpType.digits.copyWith(color: _config.color),
      ),
      textDirection: TextDirection.ltr,
      textScaler: _config.scaler,
    )..layout(),
  );

  double _slotLeft(int i) => i * _slot + (i >= 5 ? _slot * .55 : 0);

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _config.clock.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _config.clock.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    for (final p in _glyphs.values) {
      p.dispose();
    }
    super.dispose();
  }

  @override
  void performLayout() {
    size = constraints.constrain(Size(_slot * 10.55, _height));
  }

  @override
  double computeMinIntrinsicHeight(double width) => _height;
  @override
  double computeMaxIntrinsicHeight(double width) => _height;
  @override
  double computeMinIntrinsicWidth(double height) => _slot * 10.55;
  @override
  double computeMaxIntrinsicWidth(double height) => _slot * 10.55;

  static const _drop = Cubic(.2, 1.4, .4, 1); // lands with a small give

  @override
  void paint(PaintingContext context, Offset offset) {
    final c = _config;
    final canvas = context.canvas;
    final t = c.clock.value;
    final mid = offset.dy + size.height / 2;
    final n = math.min(c.digits.length, 10);

    for (var i = 0; i < 10; i++) {
      final cx = offset.dx + _slotLeft(i) + _slot / 2;
      if (i < n) {
        final glyph = _glyph(c.digits[i]);
        final p = c.reduced ? 1.0 : ((t - c.born[i]) / .22).clamp(0.0, 1.0);
        final e = _drop.transform(p);
        canvas.save();
        canvas.translate(cx, mid - 7 * (1 - e));
        canvas.scale(.7 + .3 * e);
        if (p < 1) {
          canvas.saveLayer(null, Paint()..color = AdColors.ink.withValues(alpha: math.min(1, p * 2.5)));
        }
        glyph.paint(canvas, Offset(-glyph.width / 2, -glyph.height / 2));
        if (p < 1) canvas.restore();
        canvas.restore();
      } else {
        final p = c.reduced ? 1.0 : ((t - c.dotBack[i]) / .18).clamp(0.0, 1.0);
        final r = c.scaler.scale(3.5) * cssEaseOut.transform(p);
        if (r > 0) {
          canvas.drawCircle(Offset(cx, mid), r, Paint()..color = AdColors.placeholder.withValues(alpha: .7));
        }
      }
    }

    // the caret: solid while typing, then a slow blink (on .53 s, off .53 s)
    if (c.caret) {
      final since = t - c.lastEdit;
      final on = c.reduced || since < .5 || (since % 1.06) < .53;
      if (on) {
        final x = offset.dx + (n >= 10 ? _slotLeft(9) + _slot + 2 : _slotLeft(n) - 1);
        final h = c.scaler.scale(26);
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x - 1, mid - h / 2, 2, h), const Radius.circular(1)),
          Paint()..color = AdColors.vermilion,
        );
      }
    }
  }
}

/// Keeps the field to ten digits shown as `98765 43210`, whatever is typed or pasted (GI-20, GI-22).
/// A pasted number with another country's code empties the field and reports it (GI-23).
class IndianPhoneFormatter extends TextInputFormatter {
  IndianPhoneFormatter({this.onForeign});

  final ValueChanged<bool>? onForeign;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text;
    final trimmed = raw.trimLeft();
    final explicit = trimmed.startsWith('+') || trimmed.startsWith('00');
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (trimmed.startsWith('00')) digits = digits.substring(math.min(2, digits.length));

    if (explicit && digits.length > 2 && !digits.startsWith('91')) {
      onForeign?.call(true);
      return const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0));
    }
    onForeign?.call(false);
    if (explicit && digits.startsWith('91')) {
      digits = digits.substring(2);
    } else if (digits.length > 10 && digits.startsWith('91')) {
      digits = digits.substring(2);
    } else if (digits.length > 10 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.length > 10) digits = digits.substring(0, 10);
    final text = digits.length > 5 ? '${digits.substring(0, 5)} ${digits.substring(5)}' : digits;

    // keep the caret where the person was typing, counted in digits
    final beforeCaret = newValue.selection.isValid
        ? raw.substring(0, newValue.selection.extentOffset.clamp(0, raw.length)).replaceAll(RegExp(r'\D'), '').length
        : digits.length;
    final pasted = raw.length - oldValue.text.length > 1;
    var at = pasted ? text.length : math.min(beforeCaret, digits.length);
    if (at > 5) at += 1; // the space
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: math.min(at, text.length)),
    );
  }
}
