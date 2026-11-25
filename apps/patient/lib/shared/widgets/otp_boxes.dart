import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Material, MaterialType, TextField, InputDecoration;

import '../../core/theme/tokens.dart';

/// Six code boxes over one real input (GS2, SI2): iOS fills it from the message (`oneTimeCode`), pasting a 6-digit
/// code fills every box, and screen readers hear one field, "6-digit code" (GI-61).
///
/// [onCompleted] fires exactly once per code, the moment the sixth digit lands (a pasted or autofilled code too).
/// Each change of [errorCount] shakes the boxes with a haptic (GI-25).
class OtpBoxes extends StatefulWidget {
  const OtpBoxes({
    super.key,
    required this.controller,
    required this.onCompleted,
    this.focusNode,
    this.autofocus = true,
    this.enabled = true,
    this.error = false,
    this.errorCount = 0,
  });

  final TextEditingController controller;
  final ValueChanged<String> onCompleted;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool enabled;

  /// Shows the boxes in the error colour.
  final bool error;

  /// Bump to shake.
  final int errorCount;

  static const length = 6;

  @override
  State<OtpBoxes> createState() => _OtpBoxesState();
}

class _OtpBoxesState extends State<OtpBoxes> with SingleTickerProviderStateMixin {
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  String? _sent;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _focus.addListener(_refresh);
  }

  @override
  void didUpdateWidget(OtpBoxes old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
    if (widget.errorCount != old.errorCount && widget.errorCount > 0) {
      _sent = null; // the same code may be tried again after an error
      HapticFeedback.heavyImpact();
      if (!MediaQuery.disableAnimationsOf(context)) _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _focus.removeListener(_refresh);
    if (widget.focusNode == null) _focus.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  void _changed() {
    final code = widget.controller.text;
    setState(() {});
    if (code.length < OtpBoxes.length) {
      _sent = null;
      return;
    }
    if (code != _sent && widget.enabled) {
      _sent = code;
      widget.onCompleted(code);
    }
  }

  /// With large text each digit grows as far as its box allows, keeping 8 px of air on each side (GI-60).
  static TextScaler digitScaler(TextScaler scaler, double boxWidth) {
    final p = TextPainter(
      text: TextSpan(text: '8', style: AdType.otpDigit),
      textDirection: TextDirection.ltr,
    )..layout();
    final atOne = p.width;
    p.dispose();
    final fits = (boxWidth - 2 * 2 - 16) / atOne;
    final size = AdType.otpDigit.fontSize!;
    final asked = scaler.scale(size) / size;
    return asked <= fits ? scaler : TextScaler.linear(fits.clamp(1.0, asked));
  }

  // a damped side-to-side shake: 0, -10, 10, -8, 8, -4, 0 px
  double _shakeAt(double t) {
    const pts = [0.0, -10.0, 10.0, -8.0, 8.0, -4.0, 0.0];
    final x = t * (pts.length - 1);
    final i = x.floor().clamp(0, pts.length - 2);
    final f = x - i;
    return pts[i] + (pts[i + 1] - pts[i]) * f;
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 8.0;
        final w = math.min(52.0, (box.maxWidth - gap * (OtpBoxes.length - 1)) / OtpBoxes.length);
        final scaler = digitScaler(MediaQuery.textScalerOf(context), w);
        final boxHeight = math.max(58.0, scaler.scale(28) * 1.1 + 22);
        final boxes = Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < OtpBoxes.length; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              _Box(
                width: w,
                height: boxHeight,
                digit: i < code.length ? code[i] : null,
                current: _focus.hasFocus && i == math.min(code.length, OtpBoxes.length - 1) && code.length < 6,
                error: widget.error,
              ),
            ],
          ],
        );
        return AnimatedBuilder(
          animation: _shake,
          builder: (context, child) => Transform.translate(offset: Offset(_shakeAt(_shake.value), 0), child: child),
          child: SizedBox(
            height: boxHeight,
            child: Stack(
              children: [
                ExcludeSemantics(
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(textScaler: scaler),
                    child: boxes,
                  ),
                ),
                Positioned.fill(
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
                          enabled: widget.enabled,
                          keyboardType: TextInputType.number,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(OtpBoxes.length),
                          ],
                          showCursor: false,
                          enableInteractiveSelection: true,
                          style: const TextStyle(color: Color(0x00000000), fontSize: 1),
                          decoration: const InputDecoration.collapsed(hintText: null),
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

class _Box extends StatelessWidget {
  const _Box({
    required this.width,
    required this.height,
    required this.digit,
    required this.current,
    required this.error,
  });

  final double width, height;
  final String? digit;
  final bool current, error;

  @override
  Widget build(BuildContext context) {
    final filled = digit != null;
    final color = error ? AdColors.vermilion : (current || filled ? AdColors.ink : AdColors.fieldBorder);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AdColors.white,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: color, width: current || error ? 2 : 1.5),
        boxShadow: current && !error ? const [BoxShadow(color: AdColors.focusRing, spreadRadius: 4)] : const [],
      ),
      child: Text(digit ?? '', style: AdType.otpDigit.copyWith(color: error ? AdColors.vermilion : AdColors.ink)),
    );
  }
}
