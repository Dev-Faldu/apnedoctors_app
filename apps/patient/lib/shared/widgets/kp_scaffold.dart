import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/theme/tokens.dart';

/// The page every Getting-in screen sits on: warm paper, 24 px sides, a back chevron when there is somewhere to go
/// back to, a body that scrolls when text is large (GI-60), and a bottom action area that stays above the keyboard
/// on small phones (GI-63).
class KpScaffold extends StatelessWidget {
  const KpScaffold({super.key, required this.body, this.bottom, this.onBack, this.top});

  /// The screen's content, under the top row.
  final Widget body;

  /// The main action(s), pinned above the keyboard.
  final Widget? bottom;

  /// Shows the back chevron. Android's back gesture does the same (GI-64).
  final VoidCallback? onBack;

  /// Something small beside the back chevron (the living "a", a step count).
  final Widget? top;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom;
    final safeBottom = math.max(16.0, mq.padding.bottom);
    return ColoredBox(
      color: AdColors.paper,
      child: Padding(
        padding: EdgeInsets.only(top: mq.padding.top, bottom: keyboard > 0 ? keyboard + 12 : safeBottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 56,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AdSpace.side - 12),
                child: Row(
                  children: [
                    if (onBack != null) BackChevron(onTap: onBack!) else const SizedBox(width: 48),
                    Expanded(child: Center(child: top ?? const SizedBox.shrink())),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(AdSpace.side, 8, AdSpace.side, 16),
                      child: body,
                    ),
                  ),
                  // a soft paper edge where the content scrolls under the bottom actions, instead of a hard cut
                  if (bottom != null)
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 20,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [AdColors.paperClear, AdColors.paper],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (bottom != null)
              Padding(padding: const EdgeInsets.fromLTRB(AdSpace.side, 8, AdSpace.side, 0), child: bottom),
          ],
        ),
      ),
    );
  }
}

/// A drawn back chevron in a 48 × 48 touch area.
class BackChevron extends StatelessWidget {
  const BackChevron({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: const SizedBox(width: 48, height: 48, child: CustomPaint(painter: _Chevron())),
      ),
    );
  }
}

class _Chevron extends CustomPainter {
  const _Chevron();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2 - 12, size.height / 2 - 12);
    canvas.drawPath(
      Path()
        ..moveTo(15, 5)
        ..lineTo(8, 12)
        ..lineTo(15, 19),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = AdColors.ink,
    );
  }

  @override
  bool shouldRepaint(_Chevron old) => false;
}
