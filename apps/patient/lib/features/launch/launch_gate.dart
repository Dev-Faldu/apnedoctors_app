import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../opening/opening_screen.dart';
import '../welcome/doctors_online.dart';
import '../welcome/welcome_host.dart';
import 'launch_store.dart';

/// Picks what the person sees when the app opens.
///
/// - First open ever: the full opening into Welcome; `openedBefore` is set once Welcome is shown (GI-01).
/// - Opened before (signed out): Welcome's own entrance (GI-03).
/// - Reduced motion: Welcome's settled frame, no opening (GI-62); Welcome is shown at once, so it counts.
/// The full router (`decideLaunch`) takes over from here as the sign-in screens arrive.
class LaunchGate extends ConsumerWidget {
  const LaunchGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = ref.watch(launchKindProvider);
    final online = ref.watch(doctorsOnlineProvider).value;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final store = ref.read(launchStoreProvider);
    if (reduced) {
      if (!store.openedBefore) store.markOpened();
      return WelcomeHost(reduced: true, doctorsOnline: online);
    }
    return switch (kind) {
      LaunchKind.firstOpen => OpeningScreen(doctorsOnline: online, onSettled: store.markOpened),
      LaunchKind.returning => WelcomeHost(doctorsOnline: online),
    };
  }
}
