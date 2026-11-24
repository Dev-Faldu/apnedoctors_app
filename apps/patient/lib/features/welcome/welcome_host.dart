import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'doctors_online.dart';
import 'welcome_screen.dart';
import 'welcome_timings.dart';

/// Welcome on its own (opened before, or reduced motion), with its own clock for the idle life.
class WelcomeHost extends StatefulWidget {
  const WelcomeHost({
    super.key,
    this.reduced = false,
    this.doctorsOnline,
    this.onGetStarted,
    this.onSignIn,
    this.onForDoctors,
  });

  /// Reduced motion: the settled frame, nothing moves (EC-LAUNCH-07).
  final bool reduced;
  final DoctorsOnline? doctorsOnline;
  final VoidCallback? onGetStarted;
  final VoidCallback? onSignIn;
  final VoidCallback? onForDoctors;

  @override
  State<WelcomeHost> createState() => _WelcomeHostState();
}

class _WelcomeHostState extends State<WelcomeHost> with SingleTickerProviderStateMixin {
  final _time = ValueNotifier<double>(0);
  Ticker? _ticker;

  @override
  void initState() {
    super.initState();
    if (widget.reduced) {
      _time.value = WelcomeTimings.standalone.settled;
    } else {
      _ticker = createTicker((e) => _time.value = e.inMicroseconds / 1e6)..start();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WelcomeScreen(
      time: _time,
      timings: WelcomeTimings.standalone,
      reduced: widget.reduced,
      doctorsOnline: widget.doctorsOnline,
      onGetStarted: widget.onGetStarted,
      onSignIn: widget.onSignIn,
      onForDoctors: widget.onForDoctors,
    );
  }
}
