import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/theme/tokens.dart';
import 'basics.dart';

/// "when were you born?": a month wheel and a year wheel on a white card. The chosen row sits in a vermilion band with
/// a painted white dot border along its edges; anything inside the band turns white, so a row rolling through it is
/// split cleanly at the edge. A soft tick on every row (haptics). Tap a row to jump to it.
///
/// Screen readers get two adjustable controls, "Birth month" and "Birth year", that step one at a time (GI-61).
class BirthWheel extends StatefulWidget {
  const BirthWheel({
    super.key,
    required this.month,
    required this.year,
    required this.firstYear,
    required this.lastYear,
    required this.onChanged,
    this.rows = 5,
  });

  /// 1–12.
  final int month;
  final int year;
  final int firstYear;
  final int lastYear;
  final void Function(int month, int year) onChanged;

  /// Rows showing: 5, or 3 on a short phone.
  final int rows;

  @override
  State<BirthWheel> createState() => _BirthWheelState();
}

class _BirthWheelState extends State<BirthWheel> {
  late final _months = FixedExtentScrollController(initialItem: widget.month - 1);
  late final _years = FixedExtentScrollController(initialItem: widget.year - widget.firstYear);
  late int _month = widget.month;
  late int _year = widget.year;

  @override
  void didUpdateWidget(BirthWheel old) {
    super.didUpdateWidget(old);
    // set from outside (a saved draft, "Change it"): turn the wheels there
    if (widget.month != _month && _months.hasClients) {
      _month = widget.month;
      _months.jumpToItem(widget.month - 1);
    }
    if (widget.year != _year && _years.hasClients) {
      _year = widget.year;
      _years.jumpToItem(widget.year - widget.firstYear);
    }
  }

  @override
  void dispose() {
    _months.dispose();
    _years.dispose();
    super.dispose();
  }

  void _pickMonth(int i) {
    final m = i + 1;
    if (m == _month) return;
    HapticFeedback.selectionClick();
    setState(() => _month = m);
    widget.onChanged(_month, _year);
  }

  void _pickYear(int i) {
    final y = widget.firstYear + i;
    if (y == _year) return;
    HapticFeedback.selectionClick();
    setState(() => _year = y);
    widget.onChanged(_month, _year);
  }

  void _step(FixedExtentScrollController c, int by, int count) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final to = (c.selectedItem + by).clamp(0, count - 1);
    if (reduced) {
      c.jumpToItem(to);
    } else {
      c.animateToItem(to, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    // the rows grow with the text size, up to a point, so the wheel never becomes a single row (GI-60)
    final scale = math.min(MediaQuery.textScalerOf(context).scale(10) / 10, 1.5);
    final extent = math.max(44.0, 24 * scale * 1.4);
    final height = extent * widget.rows;
    final bandTop = extent * (widget.rows - 1) / 2;
    final count = widget.lastYear - widget.firstYear + 1;

    Widget wheel({
      required FixedExtentScrollController controller,
      required int itemCount,
      required int selected,
      required String Function(int) text,
      required ValueChanged<int> onPick,
      required String label,
    }) {
      return Semantics(
        label: label,
        value: text(selected),
        increasedValue: selected + 1 < itemCount ? text(selected + 1) : null,
        decreasedValue: selected > 0 ? text(selected - 1) : null,
        onIncrease: selected + 1 < itemCount ? () => _step(controller, 1, itemCount) : null,
        onDecrease: selected > 0 ? () => _step(controller, -1, itemCount) : null,
        child: ExcludeSemantics(
          child: ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: extent,
            diameterRatio: 2.4,
            perspective: .0025,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: onPick,
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: itemCount,
              builder: (context, i) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _step(controller, i - controller.selectedItem, itemCount),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 120),
                        style: i == selected ? KpType.wheelChosen : KpType.wheelOther,
                        child: Text(text(i), maxLines: 1),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.5,
      child: Container(
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(color: AdColors.white, borderRadius: BorderRadius.all(Radius.circular(24))),
        child: Stack(
          children: [
            // the band behind the chosen row
            Positioned(
              left: 8,
              right: 8,
              top: bandTop,
              height: extent,
              child: const CustomPaint(painter: _BandPainter()),
            ),
            // everything painted inside the band turns white; outside it stays muted
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (r) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: const [
                  AdColors.muted,
                  AdColors.muted,
                  AdColors.white,
                  AdColors.white,
                  AdColors.muted,
                  AdColors.muted,
                ],
                stops: [
                  0,
                  bandTop / height,
                  bandTop / height,
                  (bandTop + extent) / height,
                  (bandTop + extent) / height,
                  1,
                ],
              ).createShader(r),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: wheel(
                      controller: _months,
                      itemCount: 12,
                      selected: _month - 1,
                      text: (i) => monthNames[i],
                      onPick: _pickMonth,
                      label: 'Birth month',
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: wheel(
                      controller: _years,
                      itemCount: count,
                      selected: _year - widget.firstYear,
                      text: (i) => '${widget.firstYear + i}',
                      onPick: _pickYear,
                      label: 'Birth year',
                    ),
                  ),
                ],
              ),
            ),
            // a line between the wheels, broken by the band
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _DividerPainter(bandTop: bandTop, extent: extent),
                ),
              ),
            ),
            // the rows fade into the card at the top and bottom
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: bandTop * .8,
              child: const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AdColors.white, AdColors.whiteClear],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: bandTop * .8,
              child: const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [AdColors.white, AdColors.whiteClear],
                    ),
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

/// The vermilion band with white painted dots along its top and bottom edges.
class _BandPainter extends CustomPainter {
  const _BandPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14));
    canvas.drawRRect(r, Paint()..color = AdColors.vermilion);
    final dot = Paint()..color = AdColors.white.withValues(alpha: .8);
    const gap = 9.0;
    final n = ((size.width - 28) / gap).floor();
    final x0 = (size.width - (n - 1) * gap) / 2;
    for (var i = 0; i < n; i++) {
      canvas.drawCircle(Offset(x0 + i * gap, 4.5), 1.3, dot);
      canvas.drawCircle(Offset(x0 + i * gap, size.height - 4.5), 1.3, dot);
    }
  }

  @override
  bool shouldRepaint(_BandPainter old) => false;
}

class _DividerPainter extends CustomPainter {
  const _DividerPainter({required this.bandTop, required this.extent});
  final double bandTop;
  final double extent;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width * 3 / 5;
    final p = Paint()
      ..color = AdColors.softLine
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(x, 12), Offset(x, bandTop - 6), p);
    canvas.drawLine(Offset(x, bandTop + extent + 6), Offset(x, size.height - 12), p);
  }

  @override
  bool shouldRepaint(_DividerPainter old) => old.bandTop != bandTop || old.extent != extent;
}
