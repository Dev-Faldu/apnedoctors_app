import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/tokens.dart';
import 'about_you_parts.dart';

/// Opens the phone's dialler with a number. Tests swap in their own.
typedef Dialler = Future<void> Function(String number);

final diallerProvider = Provider<Dialler>(
  (ref) => (number) async {
    try {
      await launchUrl(Uri(scheme: 'tel', path: number));
    } catch (_) {
      // no dialler (a tablet): the number is on the screen to call another way
    }
  },
);

/// "Want to talk to someone? Childline, free, any time. 1098": tap to call (G12, GI-41).
class ChildlineCard extends ConsumerWidget {
  const ChildlineCard({super.key});

  static const number = '1098';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // with large text the number moves under the words, so nothing is squeezed (GI-60)
    final big = MediaQuery.textScalerOf(context).scale(10) / 10 > 1.3;
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Want to talk to someone?', style: KpType.rowTitle),
        const SizedBox(height: 2),
        Text('Childline, free, any time', style: KpType.rowSub),
        if (big) ...[const SizedBox(height: 4), Text(number, style: KpType.helpline)],
      ],
    );
    return Semantics(
      button: true,
      label: 'Call Childline, 1098. Free, any time.',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => ref.read(diallerProvider)(number),
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.fromLTRB(16, 14, 18, 14),
          decoration: const BoxDecoration(color: AdColors.white, borderRadius: BorderRadius.all(Radius.circular(22))),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AdColors.paper, shape: BoxShape.circle),
                child: const TalkMark(),
              ),
              const SizedBox(width: 14),
              Expanded(child: words),
              if (!big) ...[const SizedBox(width: 10), Text(number, style: KpType.helpline)],
            ],
          ),
        ),
      ),
    );
  }
}
