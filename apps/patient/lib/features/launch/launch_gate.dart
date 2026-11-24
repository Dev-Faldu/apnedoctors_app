import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../opening/opening_screen.dart';
import '../welcome/doctors_online.dart';
import '../welcome/welcome_host.dart';
import 'launch_store.dart';

/// Picks what the person sees when the app opens.
///
/// - First open ever: the full opening into Welcome (EC-LAUNCH-01).
/// - Opened before (signed out; sign-in is the next milestone): Welcome's own entrance.
/// - Reduced motion: Welcome's settled frame, no opening (EC-LAUNCH-07).
class LaunchGate extends ConsumerWidget {
  const LaunchGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = ref.watch(launchKindProvider);
    final online = ref.watch(doctorsOnlineProvider).value;
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced) return WelcomeHost(reduced: true, doctorsOnline: online);
    return switch (kind) {
      LaunchKind.firstOpen => OpeningScreen(doctorsOnline: online),
      LaunchKind.returning => WelcomeHost(doctorsOnline: online),
    };
  }
}
