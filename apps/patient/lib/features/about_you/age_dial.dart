import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/theme/tokens.dart';
import 'about_you_parts.dart';

/// "about how old are you?": a big age between a minus and a plus. Hold a button to run through the years (faster
/// the longer you hold), or drag the number up and down. The digits roll.
///
/// Below [min] it doesn't go: [onBelowMin] says why instead (GI-46). Screen readers get one adjustable control.
class AgeDial extends StatefulWidget {
  const AgeDial({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onBelowMin,
    this.compact = false,
  });

  /// A short phone: the number is a little smaller.
  final bool compact;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final VoidCallback onBelowMin;

  @override
  State<AgeDial> createState() => _AgeDialState();
}

class _AgeDialState extends State<AgeDial> {
  Timer? _repeat;
  bool _up = true;
  double _drag = 0;

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  bool _step(int by) {
    final next = widget.value + by;
    if (next < widget.min) {
      widget.onBelowMin();
      return false;
    }
    if (next > widget.max) return false;
    HapticFeedback.selectionClick();
    setState(() => _up = by > 0);
    widget.onChanged(next);
    return true;
  }

  void _hold(int by) {
    if (!_step(by)) return;
    var wait = 380;
    var count = 0;
    void tick() {
      _repeat = Timer(Duration(milliseconds: wait), () {
        if (!mounted || !_step(by)) return;
        count++;
        wait = count < 6 ? 110 : (count < 16 ? 70 : 45);
        tick();
      });
    }

    tick();
  }

  void _release() {
    _repeat?.cancel();
    _repeat = null;
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.value;
    return Semantics(
      label: 'Your age',
      value: 'about $v years',
      increasedValue: v < widget.max ? 'about ${v + 1} years' : null,
      // at the youngest an estimate can be, "less" explains instead (GI-46)
      decreasedValue: 'about ${math.max(widget.min, v - 1)} years',
      onIncrease: v < widget.max ? () => _step(1) : null,
      onDecrease: () => _step(-1),
      child: ExcludeSemantics(
        child: Row(
          children: [
            _RoundButton(plus: false, enabled: true, onDown: () => _hold(-1), onUp: _release),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: (_) => _drag = 0,
                onVerticalDragUpdate: (d) {
                  _drag -= d.delta.dy;
                  while (_drag >= 16) {
                    _drag -= 16;
                    _step(1);
                  }
                  while (_drag <= -16) {
                    _drag += 16;
                    _step(-1);
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // already as big as a number gets: it doesn't grow with the text size, and shrinks to fit
                    MediaQuery.withNoTextScaling(
                      child: SizedBox(
                        height: widget.compact ? 88 : 104,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: RollingNumber(value: v, style: KpType.bigAge, up: _up),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('years old', style: KpType.bigAgeUnit, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            _RoundButton(plus: true, enabled: v < widget.max, onDown: () => _hold(1), onUp: _release),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatefulWidget {
  const _RoundButton({required this.plus, required this.enabled, required this.onDown, required this.onUp});
  final bool plus;
  final bool enabled;
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  State<_RoundButton> createState() => _RoundButtonState();
}

class _RoundButtonState extends State<_RoundButton> {
  bool _down = false;

  void _set(bool down) {
    if (_down == down) return;
    setState(() => _down = down);
    down ? widget.onDown() : widget.onUp();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: widget.enabled ? (_) => _set(true) : null,
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? .92 : 1,
        duration: const Duration(milliseconds: 110),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _down ? AdColors.ink : (widget.enabled ? AdColors.white : AdColors.lockedFill),
            border: Border.all(
              color: _down ? AdColors.ink : (widget.enabled ? AdColors.fieldBorder : AdColors.lockedBorder),
              width: 1.5,
            ),
          ),
          child: PlusMinusMark(
            plus: widget.plus,
            color: _down ? AdColors.paper : (widget.enabled ? AdColors.ink : AdColors.placeholder),
          ),
        ),
      ),
    );
  }
}
