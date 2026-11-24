import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../welcome/doctors_online.dart';
import '../welcome/doorway_painter.dart';
import '../welcome/welcome_screen.dart';
import '../welcome/welcome_timings.dart';
import 'opening_choreography.dart';
import 'opening_spec.g.dart';
import 'splash_painter.dart';

/// The first open: native splash → splash (the a, the alpana, the name writing itself) → hand-off
/// into Welcome. One clock drives it all; Welcome is mounted underneath from the first frame and the
/// splash hands its a over to Welcome's doorway, exactly as on the N00Splash board.
///
/// Tap anywhere to skip: the clock fast-forwards to the settled Welcome in about 0.6 s, so nothing
/// jumps. If the app is backgrounded mid-opening it finishes instantly on return (EC-LAUNCH-12).
class OpeningScreen extends StatefulWidget {
  const OpeningScreen({
    super.key,
    this.doctorsOnline,
    this.onGetStarted,
    this.onSignIn,
    this.onForDoctors,
    this.onSettled,
  });

  final DoctorsOnline? doctorsOnline;
  final VoidCallback? onGetStarted;
  final VoidCallback? onSignIn;
  final VoidCallback? onForDoctors;

  /// Called once, when the hand-off has settled into Welcome.
  final VoidCallback? onSettled;

  @override
  State<OpeningScreen> createState() => OpeningScreenState();
}

@visibleForTesting
class OpeningScreenState extends State<OpeningScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _time = ValueNotifier<double>(0);
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _rate = 1;
  bool _settledFired = false;

  final _stackKey = GlobalKey();
  final _heroKey = GlobalKey();
  Size? _size;
  DoorwayTarget? _target;
  OpeningChoreography? _choreography;

  static const settled = OpeningChoreography.settled;

  // While the a glides into the doorway (hand-off until settled), the doctors chip may update its
  // number but never appear or vanish: that would move the doorway under the a. Such a change waits
  // until Welcome has settled, then slides in or out.
  bool _holding = false;
  DoctorsOnline? _held;

  static bool _hasChip(DoctorsOnline? d) => d != null && d.count > 0;

  DoctorsOnline? get _online {
    final live = widget.doctorsOnline;
    if (!_holding || _hasChip(live) == _hasChip(_held)) return live;
    return _held;
  }

  /// Current time on the opening clock (s).
  @visibleForTesting
  double get time => _time.value;

  @visibleForTesting
  bool get fastForwarding => _rate > 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    var dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt > .25) dt = .25; // a long stall (debugger, background) never jumps the motion
    var t = _time.value + dt * _rate;
    if (_rate > 1 && t >= settled) {
      t = settled;
      _rate = 1;
    }
    _time.value = t;
    if (!_holding && !_settledFired && t >= OpeningSpec.handoff && t < settled) {
      setState(() {
        _holding = true;
        _held = widget.doctorsOnline;
      });
    } else if (_holding && t >= settled) {
      setState(() => _holding = false);
    }
    if (!_settledFired && t >= settled) {
      _settledFired = true;
      widget.onSettled?.call();
    }
  }

  /// Fast-forward to the settled Welcome.
  void skip() {
    final t = _time.value;
    if (t >= settled || _rate > 1) return;
    _rate = math.max(1, (settled - t) / .6);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _time.value < settled) {
      _rate = 1;
      _time.value = settled;
    }
  }

  void _measureDoorway() {
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final hero = _heroKey.currentContext?.findRenderObject() as RenderBox?;
    if (stack == null || hero == null || !hero.hasSize) return;
    final g = DoorwayGeometry(hero.size);
    final origin = hero.localToGlobal(Offset.zero, ancestor: stack);
    final target = DoorwayTarget(bowl: origin + g.aBowl, scale: g.aScale);
    final old = _target;
    if (old == null || (old.bowl - target.bowl).distance > .01 || (old.scale - target.scale).abs() > 1e-4) {
      setState(() {
        _target = target;
        _choreography = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        if (_choreography == null || _size != size) {
          _size = size;
          _choreography = OpeningChoreography(screen: size, doorway: _target);
        }
        final c = _choreography!;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) _measureDoorway();
        });
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: skip,
          child: Stack(
            key: _stackKey,
            children: [
              Positioned.fill(
                child: WelcomeScreen(
                  time: _time,
                  timings: WelcomeTimings.handoff,
                  heroOffset: c.heroOffset,
                  heroKey: _heroKey,
                  doctorsOnline: _online,
                  onGetStarted: widget.onGetStarted,
                  onSignIn: widget.onSignIn,
                  onForDoctors: widget.onForDoctors,
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: SplashPainter(time: _time, choreography: c),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
