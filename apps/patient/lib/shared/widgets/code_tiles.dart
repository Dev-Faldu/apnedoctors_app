import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Material, MaterialType, TextField, InputDecoration;

import '../../core/motion/keyframes.dart';
import '../../core/theme/tokens.dart';
import 'hold_scroll.dart';

/// What the code tiles are showing.
enum CodeLook {
  /// Waiting for digits.
  typing,

  /// Six digits in, the server is checking: the tiles ripple in a slow wave.
  checking,

  /// The code didn't match: a red shake, then the digits drop out and it is ready again.
  wrong,

  /// The code worked: the tiles turn green one after another.
  verified,

  /// Can't be typed into right now (expired, too many tries).
  locked,
}

/// The code (GS2, SI2): six painted tiles in two groups of three, the same language as the phone number's slots. An
/// empty tile holds a painted dot; the next one holds the vermilion caret; each digit drops in. One real (invisible)
/// text field underneath does the typing, pasting and one-time-code autofill, and screen readers hear one field,
/// "6-digit code" (GI-61).
///
/// [onCompleted] fires once per code, the moment the sixth digit lands (a pasted or autofilled code too), and only
/// while [look] is [CodeLook.typing]. Each rise of [wrongCount] shakes the tiles with a haptic and, after a beat,
/// clears them (GI-25).
class CodeTiles extends StatefulWidget {
  const CodeTiles({
    super.key,
    required this.controller,
    required this.onCompleted,
    this.focusNode,
    this.autofocus = false,
    this.look = CodeLook.typing,
    this.wrongCount = 0,
    this.holdScroll = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onCompleted;
  final FocusNode? focusNode;
  final bool autofocus;
  final CodeLook look;
  final int wrongCount;

  /// The screen decides what scrolls into view when the keyboard opens.
  final bool holdScroll;

  static const length = 6;

  @override
  State<CodeTiles> createState() => _CodeTilesState();
}

class _CodeTilesState extends State<CodeTiles> with TickerProviderStateMixin {
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final Ticker _ticker = createTicker(_tick);
  final _clock = ValueNotifier<double>(0);
  double _base = 0;

  final _born = List<double>.filled(CodeTiles.length, -10);
  final _ghostAt = List<double>.filled(CodeTiles.length, -10);
  final _ghost = List<String>.filled(CodeTiles.length, '');
  double _lookSince = 0;
  double _lastEdit = -10;
  String _shown = '';
  String? _sent;
  Timer? _clear;

  @override
  void initState() {
    super.initState();
    _shown = widget.controller.text;
    widget.controller.addListener(_changed);
    _focus.addListener(_focused);
  }

  @override
  void didUpdateWidget(CodeTiles old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
    if (widget.look != old.look) {
      _lookSince = _clock.value;
      if (widget.look == CodeLook.typing) _sent = null; // the same code may be tried again
      _wake();
    }
    if (widget.wrongCount != old.wrongCount && widget.wrongCount > 0) {
      HapticFeedback.heavyImpact();
      if (!_reduced) _shake.forward(from: 0);
      _clear?.cancel();
      // a pause to see the wrong code (not motion, so it stays with reduced motion too)
      _clear = Timer(const Duration(milliseconds: 700), () {
        if (mounted) widget.controller.clear();
      });
    }
  }

  @override
  void dispose() {
    _clear?.cancel();
    widget.controller.removeListener(_changed);
    _focus.removeListener(_focused);
    if (widget.focusNode == null) _focus.dispose();
    _shake.dispose();
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  bool get _reduced => MediaQuery.disableAnimationsOf(context);

  void _tick(Duration e) {
    _clock.value = _base + e.inMicroseconds / 1e6;
    final t = _clock.value;
    final busy =
        widget.look == CodeLook.checking ||
        (_focus.hasFocus && widget.look == CodeLook.typing) ||
        t - _lookSince < 1.2 ||
        t - _lastEdit < .8;
    if (!busy) {
      _base = t;
      _ticker.stop();
    }
  }

  void _wake() {
    if (!mounted || _reduced || _ticker.isActive) return;
    _ticker.start();
  }

  void _focused() {
    setState(() {});
    _wake();
  }

  void _changed() {
    final code = widget.controller.text;
    if (code != _shown) {
      final now = _clock.value;
      var first = 0;
      while (first < code.length && first < _shown.length && code[first] == _shown[first]) {
        first++;
      }
      for (var i = first; i < code.length && i < CodeTiles.length; i++) {
        _born[i] = now + (i - first) * .04;
      }
      // removed digits fall out, the last one first
      for (var i = code.length; i < _shown.length && i < CodeTiles.length; i++) {
        _ghost[i] = _shown[i];
        _ghostAt[i] = now + (_shown.length - 1 - i) * .04;
      }
      _shown = code;
      _lastEdit = now;
    }
    setState(() {});
    _wake();
    if (code.length < CodeTiles.length) {
      _sent = null;
      return;
    }
    if (code != _sent && widget.look == CodeLook.typing) {
      _sent = code;
      widget.onCompleted(code);
    }
  }

  static final _nudge = Keyframes.of(const [(0, 0), (.25, -6), (.5, 5), (.75, -3), (1, 0)]);

  @override
  Widget build(BuildContext context) {
    final locked = widget.look == CodeLook.locked || widget.look == CodeLook.verified;
    return LayoutBuilder(
      builder: (context, box) {
        final scaler = MediaQuery.textScalerOf(context);
        final paint = _TilesPaint(
          clock: _clock,
          code: _shown,
          born: List.of(_born),
          ghost: List.of(_ghost),
          ghostAt: List.of(_ghostAt),
          look: widget.look,
          lookSince: _lookSince,
          lastEdit: _lastEdit,
          focused: _focus.hasFocus,
          reduced: _reduced,
          scaler: scaler,
        );
        return AnimatedBuilder(
          animation: _shake,
          builder: (context, child) =>
              Transform.translate(offset: Offset(_nudge.at(_shake.value, 0, cssEaseInOut), 0), child: child),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: locked ? null : _focus.requestFocus,
            child: Stack(
              children: [
                ExcludeSemantics(child: paint),
                Positioned.fill(
                  child: HoldScroll(
                    hold: widget.holdScroll,
                    child: Opacity(
                      opacity: 0,
                      alwaysIncludeSemantics: true,
                      child: Semantics(
                        label: '6-digit code',
                        child: Material(
                          type: MaterialType.transparency,
                          child: TextField(
                            controller: widget.controller,
                            focusNode: _focus,
                            autofocus: widget.autofocus,
                            readOnly: locked,
                            showCursor: false,
                            keyboardType: TextInputType.number,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(CodeTiles.length),
                            ],
                            style: const TextStyle(color: Color(0x00000000), fontSize: 16),
                            decoration: const InputDecoration.collapsed(hintText: null),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TilesPaint extends LeafRenderObjectWidget {
  const _TilesPaint({
    required this.clock,
    required this.code,
    required this.born,
    required this.ghost,
    required this.ghostAt,
    required this.look,
    required this.lookSince,
    required this.lastEdit,
    required this.focused,
    required this.reduced,
    required this.scaler,
  });

  final ValueListenable<double> clock;
  final String code;
  final List<double> born;
  final List<String> ghost;
  final List<double> ghostAt;
  final CodeLook look;
  final double lookSince;
  final double lastEdit;
  final bool focused;
  final bool reduced;
  final TextScaler scaler;

  @override
  _RenderTiles createRenderObject(BuildContext context) => _RenderTiles(this);

  @override
  void updateRenderObject(BuildContext context, _RenderTiles renderObject) => renderObject.config = this;
}

class _RenderTiles extends RenderBox {
  _RenderTiles(this._c);

  _TilesPaint _c;
  set config(_TilesPaint v) {
    if (v.clock != _c.clock && attached) {
      _c.clock.removeListener(markNeedsPaint);
      v.clock.addListener(markNeedsPaint);
    }
    final relayout = v.scaler != _c.scaler;
    _c = v;
    if (relayout) {
      _glyphs.clear();
      markNeedsLayout();
    }
    markNeedsPaint();
  }

  final _glyphs = <String, TextPainter>{};

  static const _gap = 8.0, _groupGap = 22.0;

  double get _tileW => (size.width - 4 * _gap - _groupGap) / CodeTiles.length;
  double _tileLeft(int i) => i * (_tileW + _gap) + (i >= 3 ? _groupGap - _gap : 0);

  /// The digit size: the person's text size, as far as a tile's width allows (GI-60).
  double _digitSize(double tileW) {
    final asked = _c.scaler.scale(KpType.codeDigit.fontSize!);
    final probe = TextPainter(
      text: TextSpan(text: '0', style: KpType.codeDigit),
      textDirection: TextDirection.ltr,
    )..layout();
    final fits = KpType.codeDigit.fontSize! * (tileW - 16) / probe.width;
    probe.dispose();
    return math.max(KpType.codeDigit.fontSize!, math.min(asked, fits));
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _c.clock.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _c.clock.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    for (final p in _glyphs.values) {
      p.dispose();
    }
    super.dispose();
  }

  double _height(double width) {
    final tileW = (width - 4 * _gap - _groupGap) / CodeTiles.length;
    return math.max(64, _digitSize(tileW) * 1.15 + 24);
  }

  @override
  void performLayout() {
    final w = constraints.maxWidth;
    size = constraints.constrain(Size(w, _height(w)));
  }

  @override
  double computeMinIntrinsicHeight(double width) => _height(width);
  @override
  double computeMaxIntrinsicHeight(double width) => _height(width);

  TextPainter _glyph(String d, Color color, double fontSize) => _glyphs.putIfAbsent(
    '$d${color.toARGB32()}$fontSize',
    () => TextPainter(
      text: TextSpan(
        text: d,
        style: KpType.codeDigit.copyWith(color: color, fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout(),
  );

  static final _wave = Keyframes.of(const [(0, 0), (.3, -6), (.6, 0), (1, 0)]);
  static const _drop = Cubic(.2, 1.4, .4, 1);

  @override
  void paint(PaintingContext context, Offset offset) {
    final c = _c;
    final canvas = context.canvas;
    final t = c.clock.value;
    final n = math.min(c.code.length, CodeTiles.length);
    final tileW = _tileW;
    final h = size.height;
    final font = _digitSize(tileW);
    final since = t - c.lookSince;

    for (var i = 0; i < CodeTiles.length; i++) {
      var dy = 0.0, scale = 1.0;
      var fill = AdColors.white, border = AdColors.fieldBorder, width = 1.5;
      var digitColor = AdColors.ink;
      var ring = false;
      final current = c.focused && c.look == CodeLook.typing && i == math.min(n, CodeTiles.length - 1) && n < 6;
      if (i < n) border = AdColors.ink;

      switch (c.look) {
        case CodeLook.typing:
          if (current) {
            border = AdColors.ink;
            width = 2;
            ring = true;
          }
        case CodeLook.checking:
          border = AdColors.ink;
          if (!c.reduced) {
            final a = CssAnim(1, delay: i * .08, infinite: true, fill: Fill.none, curve: cssEaseInOut);
            dy = a.sample(since, _wave) ?? 0;
          }
        case CodeLook.wrong:
          border = AdColors.vermilion;
          width = 2;
          digitColor = AdColors.errorText;
        case CodeLook.verified:
          // one tile after another turns green, with a little lift
          final p = c.reduced ? 1.0 : ((since - i * .07) / .26).clamp(0.0, 1.0);
          final e = Curves.easeOut.transform(p);
          fill = Color.lerp(AdColors.white, AdColors.okFill, e)!;
          border = Color.lerp(AdColors.ink, AdColors.tick, e)!;
          width = 1.5 + .5 * e;
          digitColor = Color.lerp(AdColors.ink, AdColors.okText, e)!;
          scale = 1 + .07 * math.sin(math.pi * p);
        case CodeLook.locked:
          fill = AdColors.lockedFill;
          border = AdColors.lockedBorder;
          digitColor = AdColors.muted;
      }

      final rect = Rect.fromLTWH(offset.dx + _tileLeft(i), offset.dy + dy, tileW, h);
      canvas.save();
      if (scale != 1) {
        canvas.translate(rect.center.dx, rect.center.dy);
        canvas.scale(scale);
        canvas.translate(-rect.center.dx, -rect.center.dy);
      }
      final rr = RRect.fromRectAndRadius(rect, const Radius.circular(18));
      if (ring) {
        canvas.drawRRect(rr.inflate(4), Paint()..color = AdColors.ring);
      }
      canvas.drawRRect(rr, Paint()..color = fill);
      canvas.drawRRect(
        rr.deflate(width / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = border,
      );

      final mid = rect.center;
      if (i < n) {
        final p = c.reduced ? 1.0 : ((t - c.born[i]) / .22).clamp(0.0, 1.0);
        final e = _drop.transform(p);
        final g = _glyph(c.code[i], digitColor, font);
        canvas.save();
        canvas.translate(mid.dx, mid.dy - 8 * (1 - e));
        canvas.scale(.7 + .3 * e);
        if (p < 1) canvas.saveLayer(null, Paint()..color = AdColors.ink.withValues(alpha: math.min(1, p * 2.5)));
        g.paint(canvas, Offset(-g.width / 2, -g.height / 2));
        if (p < 1) canvas.restore();
        canvas.restore();
      } else {
        // a digit that just left falls out of its tile
        final gp = c.reduced ? 1.0 : ((t - c.ghostAt[i]) / .2).clamp(0.0, 1.0);
        if (gp < 1 && c.ghost[i].isNotEmpty) {
          final g = _glyph(c.ghost[i], digitColor, font);
          canvas.save();
          canvas.translate(mid.dx, mid.dy + 14 * Curves.easeIn.transform(gp));
          canvas.saveLayer(null, Paint()..color = AdColors.ink.withValues(alpha: 1 - gp));
          g.paint(canvas, Offset(-g.width / 2, -g.height / 2));
          canvas.restore();
          canvas.restore();
        }
        if (current) {
          final since = t - c.lastEdit;
          final on = c.reduced || since < .5 || (since % 1.06) < .53;
          if (on) {
            final ch = font * 1.0;
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(center: mid, width: 2.5, height: ch),
                const Radius.circular(1.25),
              ),
              Paint()..color = AdColors.vermilion,
            );
          }
        } else if (gp >= 1 || c.ghost[i].isEmpty) {
          final r = 4.0 * (c.look == CodeLook.locked ? .8 : 1);
          canvas.drawCircle(mid, r, Paint()..color = AdColors.placeholder.withValues(alpha: .7));
        }
      }
      canvas.restore();
    }
  }
}
