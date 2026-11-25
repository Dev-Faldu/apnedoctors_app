import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Material, MaterialType, TextField, InputDecoration;

import '../../core/theme/tokens.dart';
import '../indian_phone.dart';

/// The mobile number field (GS1, SI1, PR2): a fixed +91 chip, ten digits shown as `98765 43210`, numeric keyboard,
/// phone autofill. Typing or pasting any common form (+91, 91, 0, spaces, dashes) lands as ten digits (GI-20, GI-22);
/// another country's number is refused with a plain sentence (GI-23).
class PhoneField extends StatefulWidget {
  const PhoneField({
    super.key,
    required this.controller,
    this.onChanged,
    this.onSubmitted,
    this.onCaret,
    this.focusNode,
    this.autofocus = false,
    this.enabled = true,
    this.errorText,
  });

  /// Holds the ten digits as shown (`98765 43210`).
  final TextEditingController controller;

  /// Every change, already parsed.
  final ValueChanged<PhoneParse>? onChanged;
  final ValueChanged<PhoneParse>? onSubmitted;

  /// Where the caret is, 0–1, for the listening "a".
  final ValueChanged<double>? onCaret;

  final FocusNode? focusNode;
  final bool autofocus;
  final bool enabled;

  /// A message from outside the field (offline, too many tries). Shown instead of the field's own.
  final String? errorText;

  @override
  State<PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<PhoneField> {
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  bool _foreign = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_refresh);
    widget.controller.addListener(_caret);
  }

  @override
  void dispose() {
    _focus.removeListener(_refresh);
    widget.controller.removeListener(_caret);
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  void _caret() {
    final sel = widget.controller.selection;
    final at = sel.isValid ? sel.extentOffset : widget.controller.text.length;
    widget.onCaret?.call((at / 11).clamp(0.0, 1.0));
  }

  PhoneParse get _parse => _foreign ? const PhoneBad(PhoneProblem.notIndian) : parseIndianPhone(widget.controller.text);

  /// The last change reported, so one edit is reported once.
  String? _reported;

  /// Reports a change. A foreign paste into an empty field leaves the text empty, so the TextField itself
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

  /// The field's own message: only once all ten digits are in and they don't work, or after a foreign paste.
  String? get _ownError {
    final p = _parse;
    if (p is! PhoneBad) return null;
    if (p.problem == PhoneProblem.notIndian) return phoneProblemText(p.problem);
    final digits = widget.controller.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return phoneProblemText(p.problem);
    return null;
  }

  // the box around the digits: side padding, border, the divider and its margins
  static const _chrome = 18.0 * 2 + 2 * 2 + 12 * 2 + 1.5;

  /// At very large text the whole number must still fit on one line (GI-60): the digits grow as far as the field's
  /// width allows. The labels and messages around the field keep the person's full text size.
  static TextScaler fitScaler(TextScaler scaler, double fieldWidth) {
    double width(String text, TextStyle style) {
      final p = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      final w = p.width;
      p.dispose();
      return w;
    }

    // one spare digit's room for the caret
    final atOne = width('+91', AdType.fieldPrefix) + width('98765 432109', AdType.field);
    final fits = (fieldWidth - _chrome) / atOne;
    final size = AdType.field.fontSize!;
    final asked = scaler.scale(size) / size;
    return asked <= fits ? scaler : TextScaler.linear(fits.clamp(1.0, asked));
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.errorText ?? _ownError;
    final focused = _focus.hasFocus;
    final borderColor = error != null ? AdColors.vermilion : (focused ? AdColors.ink : AdColors.fieldBorder);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, box) {
            final scaler = fitScaler(MediaQuery.textScalerOf(context), box.maxWidth);
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: scaler),
              child: _box(scaler, borderColor, focused, error),
            );
          },
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.topLeft,
          child: error == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Semantics(liveRegion: true, child: Text(error, style: AdType.error)),
                ),
        ),
      ],
    );
  }

  Widget _box(TextScaler scaler, Color borderColor, bool focused, String? error) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      constraints: BoxConstraints(minHeight: math.max(58, scaler.scale(19) * 1.2 + 24)),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: AdColors.white,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(color: borderColor, width: focused || error != null ? 2 : 1.5),
        boxShadow: focused && error == null ? const [BoxShadow(color: AdColors.focusRing, spreadRadius: 4)] : const [],
      ),
      child: Row(
        children: [
          ExcludeSemantics(child: Text('+91', style: AdType.fieldPrefix)),
          Container(
            width: 1.5,
            height: 26,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: AdColors.fieldBorder,
          ),
          Expanded(
            child: Semantics(
              label: 'Mobile number, plus 91',
              child: Material(
                type: MaterialType.transparency,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  autofocus: widget.autofocus,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.telephoneNumberNational, AutofillHints.telephoneNumber],
                  inputFormatters: [IndianPhoneFormatter(onForeign: _foreignPaste)],
                  style: AdType.field,
                  cursorColor: AdColors.vermilion,
                  decoration: InputDecoration.collapsed(
                    hintText: '98765 43210',
                    hintStyle: AdType.field.copyWith(color: AdColors.muted.withValues(alpha: .6)),
                  ),
                  onChanged: (_) => _report(),
                  onSubmitted: (_) => widget.onSubmitted?.call(_parse),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
