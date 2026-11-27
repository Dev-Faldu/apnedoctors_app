import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/backend/online.dart';
import '../../core/motion/keyframes.dart';
import '../../core/theme/css_paragraph.dart';
import '../../core/theme/tokens.dart';
import '../../shared/indian_phone.dart';
import '../../shared/widgets/fill_column.dart';
import '../../shared/widgets/google_button.dart';
import '../../shared/widgets/kp_icons.dart';
import '../../shared/widgets/phone_field.dart';
import '../../shared/widgets/primary_button.dart';
import '../launch/launch_store.dart';
import '../welcome/doorway_hand_off.dart';
import 'code_verifier.dart';
import 'get_started_a.dart';
import 'phone_code_sender.dart';
import 'toran.dart';

/// Copy on Get started.
abstract final class GsCopy {
  static const headline = 'let’s get\nyou in.';
  static const headlineCompact = 'let’s get you in.';
  static const lede = 'Your number keeps your care in one place. We’ll text you a code.';
  static const label = 'Mobile number';
  static const send = 'Send code';
  static const sending = 'Sending code';
  static const sentButton = 'Code sent · change number';
  static String sent(PhoneOk p) => 'Code sent to +91 ${p.display}.';
  static const slow = 'This is taking longer than usual.';
  static const offline = 'You’re offline. Connect and try again.';
  static const google = 'Google sign-in isn’t working right now. Use your phone number instead.';
  static const signInQuestion = 'Already have an account? ';
  static const signIn = 'Sign in';
}

/// GS1 · G3 Sign up: "let's get you in."
///
/// You arrive by walking through Welcome's doorway: the doorway grows past you, the living "a" steps out of it and
/// glides on one curve to sit beside the headline, the toran settles across the top and the page rises in. Back plays
/// it in reverse. (Reference board: docs/design/kalighat-pop/G03GetStarted.)
///
/// - The number is the hero: ten painted dots, five and five, that become digits as you type (GI-20–23).
/// - One tap sends one request (GI-24); the server's limits show as a real countdown (GI-26); slow and failed sends
///   say so and give the button back (GI-66, GI-67).
/// - Offline: an ink pill slides in under the toran and both buttons rest (GI-12). Nothing on the page moves.
/// - Keyboard open: Send code stays above it. On a short phone the line folds away and the "a" glides up into the top
///   bar (GI-63). Large text scrolls (GI-60). Back returns to Welcome (GI-64).
class GetStartedScreen extends ConsumerStatefulWidget {
  const GetStartedScreen({
    super.key,
    this.entrance = true,
    this.flightFrom,
    this.initialPhone,
    this.onBack,
    this.onSignIn,
    this.onTerms,
    this.onPrivacy,
    this.onCodeSent,
    this.openCode,
  });

  /// The page rises in as it opens.
  final bool entrance;

  /// Where the "a" stood in Welcome's doorway: it flies from there to its seat here (and back, on Back).
  final AFlightStart? flightFrom;

  /// A number to start with (Create an account from Sign in, GI-34).
  final String? initialPhone;

  final VoidCallback? onBack;
  final VoidCallback? onSignIn;
  final VoidCallback? onTerms;
  final VoidCallback? onPrivacy;

  /// The code is on its way to this number.
  final ValueChanged<PhoneOk>? onCodeSent;

  /// Opens the code screen (GS2) and waits until it comes back: null for Back, 'change' for Change (GI-30, GI-31).
  final Future<String?> Function(CodeArrival arrival)? openCode;

  @override
  ConsumerState<GetStartedScreen> createState() => _GetStartedScreenState();
}

enum _Phase { typing, sending, sent }

class _GetStartedScreenState extends ConsumerState<GetStartedScreen> with SingleTickerProviderStateMixin {
  final _phone = TextEditingController();
  final _focus = FocusNode();
  final _clock = ValueNotifier<double>(0);
  final _scroll = ScrollController();
  final _pageKey = GlobalKey();
  final _heroKey = GlobalKey();
  final _fieldKey = GlobalKey();
  final _sendKey = GlobalKey();
  late final _terms = TapGestureRecognizer()..onTap = () => widget.onTerms?.call();
  late final _privacy = TapGestureRecognizer()..onTap = () => widget.onPrivacy?.call();
  late final Ticker _ticker = createTicker((e) => _clock.value = e.inMicroseconds / 1e6);

  _Phase _phase = _Phase.typing;
  PhoneParse _parse = const PhoneBad(PhoneProblem.empty);
  PhoneOk? _sentTo;
  String? _error;

  /// Seconds until the server lets us send again (GI-26). Counted down here, from the server's own wait.
  int? _retryLeft;
  Timer? _retryTimer;
  Timer? _slowTimer;
  bool _slow = false;
  bool _googleNote = false;
  double _validSince = 0;

  /// Where Send code ends in the regular layout (from the page top), to know when the keyboard would cover it.
  double? _regularSendBottom;

  /// Where the headline row ends, so the "a" sits on its baseline even when large text makes it taller.
  double? _heroBottom;
  double _lastKeyboard = 0;

  @override
  void initState() {
    super.initState();
    final start = widget.initialPhone;
    if (start != null) {
      final v = IndianPhoneFormatter().formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: start));
      _phone.value = v;
      _parse = parseIndianPhone(v.text);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced && _ticker.isActive) _ticker.stop();
    if (!reduced && !_ticker.isActive) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _retryTimer?.cancel();
    _slowTimer?.cancel();
    _visibleTimer?.cancel();
    _terms.dispose();
    _privacy.dispose();
    _phone.dispose();
    _focus.dispose();
    _clock.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ---- state ----------------------------------------------------------------------------------

  int get _digitCount => _phone.text.replaceAll(RegExp(r'\D'), '').length;

  bool get _wrong {
    final p = _parse;
    if (p is PhoneBad && p.problem == PhoneProblem.notIndian) return true;
    final d = _phone.text.replaceAll(RegExp(r'\D'), '');
    return d.isNotEmpty && !RegExp(r'^[6-9]').hasMatch(d);
  }

  bool get _waiting => _retryLeft != null;

  GsMood _mood(bool online) {
    if (_phase == _Phase.sending) return GsMood.thinking;
    if (!online || _error != null || _waiting) return GsMood.worried;
    if (_phase == _Phase.sent || _parse is PhoneOk) return GsMood.happy;
    if (_wrong) return GsMood.worried;
    return GsMood.listening;
  }

  void _changed(PhoneParse p) {
    setState(() {
      if (p is PhoneOk && _parse is! PhoneOk) _validSince = _clock.value;
      _parse = p;
      _error = null;
    });
  }

  Future<void> _send() async {
    final p = _parse;
    if (p is! PhoneOk || _phase != _Phase.typing || _waiting) return; // GI-24: one request at a time
    _focus.unfocus();
    setState(() {
      _phase = _Phase.sending;
      _error = null;
      _slow = false;
    });
    _slowTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) setState(() => _slow = true);
    });
    final result = await ref.read(phoneCodeSenderProvider).send(p);
    _slowTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _slow = false;
      switch (result) {
        case CodeSent():
          _phase = _Phase.sent;
          _sentTo = p;
          _sentAt = clock.now();
        case SendWait(:final wait):
          _phase = _Phase.typing;
          if (wait == null) {
            _error = SendCopy.tooManyLater;
          } else {
            _startWait(wait);
          }
        case SendFailed(:final message):
          _phase = _Phase.typing;
          _error = message;
      }
    });
    if (result is CodeSent) {
      ref.read(launchStoreProvider).setPendingCode(PendingCode(e164: p.e164, sentAt: _sentAt!));
      widget.onCodeSent?.call(p);
      await _openCode(p);
    }
  }

  DateTime? _sentAt;

  /// A beat of "Code sent", then the code screen. The number lifts out of the field and flies up into it.
  Future<void> _openCode(PhoneOk p) async {
    final open = widget.openCode;
    if (open == null) return;
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted || _phase != _Phase.sent) return;
    final arrival = CodeArrival(phone: p, sentAt: _sentAt!, numberFrom: _numberRect(), clockFrom: _clock.value);
    final result = await open(arrival);
    if (!mounted) return;
    setState(() {
      _phase = _Phase.typing; // the number stays, ready to send again or change (GI-30)
      _sentTo = null;
    });
    if (result == 'change') _focus.requestFocus();
  }

  /// Where the phone number's digits are on screen.
  Rect? _numberRect() {
    RenderDigitSlots? found;
    void visit(RenderObject o) {
      if (found != null) return;
      if (o is RenderDigitSlots) {
        found = o;
        return;
      }
      o.visitChildren(visit);
    }

    final root = _fieldKey.currentContext?.findRenderObject();
    if (root == null) return null;
    visit(root);
    final f = found;
    if (f == null || !f.attached || !f.hasSize) return null;
    return f.localToGlobal(Offset.zero) & f.size;
  }

  void _startWait(Duration wait) {
    _retryLeft = math.max(1, (wait.inMilliseconds / 1000).ceil());
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() {
        final left = _retryLeft! - 1;
        _retryLeft = left > 0 ? left : null;
        if (left <= 0) timer.cancel();
      });
    });
  }

  void _changeNumber() {
    setState(() {
      _phase = _Phase.typing;
      _sentTo = null;
      _phone.clear();
      _parse = const PhoneBad(PhoneProblem.empty);
    });
    _focus.requestFocus();
  }

  void _back() {
    final back = widget.onBack;
    if (back != null) return back();
    Navigator.of(context).maybePop();
  }

  /// The line under the field, when the screen has something to say. Null: the field's own help.
  (String?, bool) _message(bool online) {
    if (_phase == _Phase.sending) return (_slow ? GsCopy.slow : '', false);
    final sent = _sentTo;
    if (_phase == _Phase.sent && sent != null) return (GsCopy.sent(sent), false);
    if (!online) return ('', false);
    final left = _retryLeft;
    if (left != null) return (SendCopy.tooMany(Duration(seconds: left)), true);
    if (_error != null) return (_error, true);
    return (null, false);
  }

  // ---- after layout: the keyboard (GI-63) and the a's seat --------------------------------------

  void _afterLayout(double keyboard, bool compact, double viewport) {
    final page = _pageKey.currentContext?.findRenderObject() as RenderBox?;
    final send = _sendKey.currentContext?.findRenderObject() as RenderBox?;
    final field = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    final hero = _heroKey.currentContext?.findRenderObject() as RenderBox?;
    if (page == null || send == null || field == null || !page.attached) return;
    if (hero != null && hero.attached && !compact) {
      final bottom = hero.localToGlobal(Offset(0, hero.size.height), ancestor: page).dy;
      if (_heroBottom == null || (bottom - _heroBottom!).abs() > .5) {
        setState(() => _heroBottom = bottom);
      }
    }
    final sendBottom = send.localToGlobal(Offset(0, send.size.height), ancestor: page).dy;
    if (!compact && keyboard == 0) {
      _regularSendBottom = sendBottom;
    } else if (!compact && _regularSendBottom == null) {
      setState(() => _regularSendBottom = sendBottom);
      return;
    }
    if (keyboard > 0 && keyboard != _lastKeyboard) {
      // once the layout has settled (the compact fold animates), keep Send code above the keyboard
      _visibleTimer?.cancel();
      _visibleTimer = Timer(const Duration(milliseconds: 360), _keepActionVisible);
    }
    _lastKeyboard = keyboard;
  }

  Timer? _visibleTimer;

  /// Scrolls just enough for Send code to sit above the keyboard, never pushing the field off the top (GI-63).
  void _keepActionVisible() {
    if (!mounted || !_scroll.hasClients) return;
    final page = _pageKey.currentContext?.findRenderObject() as RenderBox?;
    final send = _sendKey.currentContext?.findRenderObject() as RenderBox?;
    final field = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (page == null || send == null || field == null) return;
    final mq = MediaQuery.of(context);
    final viewport = mq.size.height - mq.viewInsets.bottom;
    final sendBottom = send.localToGlobal(Offset(0, send.size.height), ancestor: page).dy;
    final fieldTop = field.localToGlobal(Offset.zero, ancestor: page).dy;
    final want = math.min(sendBottom + 12 - viewport, fieldTop - 8);
    if (want > _scroll.offset) {
      final to = want.clamp(0.0, _scroll.position.maxScrollExtent);
      if (mq.disableAnimations) {
        _scroll.jumpTo(to);
      } else {
        _scroll.animateTo(to, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
      }
    }
  }

  // ---- layout ---------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final reduced = mq.disableAnimations;
    final online = ref.watch(onlineProvider).value ?? true;
    final width = mq.size.width;
    final height = mq.size.height;
    final safeTop = mq.padding.top;
    final keyboard = mq.viewInsets.bottom;
    final viewport = height - keyboard;
    final regular = _regularSendBottom;
    final compact = keyboard > 0 && regular != null && viewport < regular + 12;
    final route = ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation;
    final flight = reduced ? null : widget.flightFrom;
    final entrance = widget.entrance && !reduced;
    final move = reduced ? const Duration(microseconds: 1) : const Duration(milliseconds: 320);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _afterLayout(keyboard, compact, viewport);
    });

    final locked = _phase != _Phase.typing;
    final (message, messageIsError) = _message(online);
    final valid = _parse is PhoneOk;

    // the page rises in once the doorway has passed
    final lag = flight != null ? .34 : .2;
    Widget rise(double order, Widget child, {Key? key}) =>
        _Rise(key: key, time: _clock, delay: lag + order * .08, enabled: entrance, child: child);

    final Widget send;
    if (_phase == _Phase.sent) {
      send = PrimaryButton(
        label: GsCopy.sentButton,
        tone: ButtonTone.ink,
        leading: const CheckMark(),
        onPressed: _changeNumber,
      );
    } else if (_phase == _Phase.sending) {
      send = PrimaryButton(label: GsCopy.send, busyLabel: GsCopy.sending, loading: true, onPressed: () {});
    } else {
      final ready = valid && online && !_waiting;
      send = PrimaryButton(
        label: GsCopy.send,
        onPressed: ready ? _send : null,
        shine: ready && !reduced ? ShineTiming(time: _clock, delay: _validSince + 1.2) : null,
      );
    }

    // while the code screen comes in on top, the toran, the back button and the a stay put there (it draws its own)
    // and everything else steps aside to the left; the number flies up
    final away = ModalRoute.of(context)?.secondaryAnimation ?? kAlwaysDismissedAnimation;
    final back = _HideWhile(
      away: away,
      child: Transform.translate(
        offset: const Offset(-12, 0),
        child: KpBackButton(onTap: _back, label: 'Back to Welcome'),
      ),
    );
    final barHeight = compact ? 56.0 : 48.0;

    final top = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          key: const ValueKey('top'),
          duration: move,
          curve: Curves.easeInOutCubic,
          height: 40 + barHeight,
          alignment: Alignment.bottomLeft,
          child: SizedBox(
            height: barHeight,
            child: Align(alignment: Alignment.centerLeft, child: back),
          ),
        ),
        AnimatedSize(
          key: const ValueKey('hero'),
          duration: move,
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topLeft,
          child: compact
              ? Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Semantics(
                    header: true,
                    child: CssParagraph(GsCopy.headlineCompact, style: KpType.h1(compact: true)),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 44),
                      child: Row(
                        key: _heroKey,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: rise(
                              0,
                              Semantics(header: true, child: CssParagraph(GsCopy.headline, style: KpType.h1())),
                            ),
                          ),
                          // the a's seat (it is drawn above the page, so it can fly in and move)
                          const SizedBox(width: 102, height: 92),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: rise(1, CssParagraph(GsCopy.lede, style: AdType.lede())),
                    ),
                  ],
                ),
        ),
        AnimatedPadding(
          key: const ValueKey('label'),
          duration: move,
          curve: Curves.easeInOutCubic,
          padding: EdgeInsets.only(top: compact ? 16 : 28, bottom: 8),
          child: rise(2, ExcludeSemantics(child: Text(GsCopy.label, style: KpType.label))),
        ),
        rise(
          key: const ValueKey('field'),
          2,
          KeyedSubtree(
            key: _fieldKey,
            child: PhoneField(
              controller: _phone,
              focusNode: _focus,
              locked: locked,
              message: message,
              messageIsError: messageIsError,
              onChanged: _changed,
              onSubmitted: (_) => _send(),
              holdScroll: true,
              away: away,
            ),
          ),
        ),
        AnimatedPadding(
          key: const ValueKey('send'),
          duration: move,
          curve: Curves.easeInOutCubic,
          padding: EdgeInsets.only(top: compact ? 12 : 16),
          child: rise(3, KeyedSubtree(key: _sendKey, child: send)),
        ),
        rise(
          key: const ValueKey('rest'),
          4,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: _Or()),
              GoogleButton(
                onPressed: online && _phase != _Phase.sending ? () => setState(() => _googleNote = true) : null,
              ),
              AnimatedSize(
                duration: move,
                curve: Curves.easeOutCubic,
                alignment: Alignment.topLeft,
                child: _googleNote
                    ? Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Semantics(
                          liveRegion: true,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: AlertMark(size: 18, color: AdColors.muted),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: CssParagraph(GsCopy.google, style: KpType.help)),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ],
    );

    final footer = rise(
      4,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(
              style: KpType.terms,
              children: [
                const TextSpan(text: 'By continuing you agree to our '),
                TextSpan(text: 'Terms', style: KpType.termsLink, recognizer: _terms),
                const TextSpan(text: ' and '),
                TextSpan(text: 'Privacy Policy', style: KpType.termsLink, recognizer: _privacy),
                const TextSpan(text: '.'),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Semantics(
            link: true,
            label: '${GsCopy.signInQuestion}${GsCopy.signIn}',
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onSignIn,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Center(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: GsCopy.signInQuestion, style: KpType.signIn),
                        TextSpan(text: GsCopy.signIn, style: KpType.signInStrong),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    // the a: beside the headline, or (short phone, keyboard open) up in the top bar
    final aScale = compact ? .56 : 1.0;
    final aLeft = compact ? width - AdSpace.side - 100 * aScale + 4 : width - AdSpace.side - 100 + 6;
    final aTop = compact ? safeTop + 40 + 3 : (_heroBottom ?? safeTop + 224) - 92;
    final a = AnimatedPositioned(
      duration: move,
      curve: Curves.easeInOutCubic,
      left: aLeft,
      top: aTop,
      child: AnimatedScale(
        duration: move,
        curve: Curves.easeInOutCubic,
        alignment: Alignment.topLeft,
        scale: aScale,
        child: _HideWhile(
          away: away,
          child: _AFlight(
            route: route,
            from: flight,
            child: GetStartedA(
              time: _clock,
              mood: _mood(online),
              digits: _digitCount,
              entrance: entrance && flight == null,
              reduced: reduced,
            ),
          ),
        ),
      ),
    );

    final page = Stack(
      children: [
        Positioned(
          top: safeTop,
          left: 0,
          right: 0,
          child: _ToranSettle(
            route: route,
            reduced: reduced,
            child: _HideWhile(
              away: away,
              child: Toran(time: _clock, reduced: reduced),
            ),
          ),
        ),
        FadeTransition(
          opacity: CurvedAnimation(parent: route, curve: const Interval(.12, .5)),
          child: _StepLeft(
            away: away,
            reduced: reduced,
            child: FillColumn(
              key: _pageKey,
              minHeight: height,
              top: Padding(padding: EdgeInsets.fromLTRB(AdSpace.side, safeTop, AdSpace.side, 0), child: top),
              bottom: Padding(
                padding: EdgeInsets.fromLTRB(AdSpace.side, 0, AdSpace.side, math.max(24, mq.padding.bottom)),
                child: footer,
              ),
            ),
          ),
        ),
        a,
        Positioned(
          top: safeTop + 8,
          left: AdSpace.side,
          right: AdSpace.side,
          child: _OfflinePill(offline: !online, reduced: reduced),
        ),
      ],
    );

    return Stack(
      children: [
        // the paper comes in behind you as you step through the doorway
        Positioned.fill(
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: route,
              curve: const Interval(.3, .7, curve: Curves.easeInOut),
            ),
            child: const ColoredBox(color: AdColors.paper),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(bottom: keyboard),
          child: SingleChildScrollView(controller: _scroll, child: page),
        ),
      ],
    );
  }
}

/// Fades up 18 px over 0.5 s (ease-out) after [delay]. Off: the child as it is.
class _Rise extends StatelessWidget {
  const _Rise({super.key, required this.time, required this.delay, required this.enabled, required this.child});
  final ValueListenable<double> time;
  final double delay;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: time,
      child: child,
      builder: (context, t, child) {
        final p = enabled ? (CssAnim(.5, delay: delay, curve: cssEaseOut).lerp(t, 0, 1) ?? 1) : 1.0;
        return Opacity(
          opacity: p,
          child: Transform.translate(offset: Offset(0, 18 * (1 - p)), child: child),
        );
      },
    );
  }
}

/// The toran drops in across the top as you come through the doorway, with a little give as it settles.
class _ToranSettle extends StatelessWidget {
  const _ToranSettle({required this.route, required this.reduced, required this.child});
  final Animation<double> route;
  final bool reduced;
  final Widget child;

  static const _settle = Interval(.42, 1, curve: Cubic(.3, 1.35, .5, 1));

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: route,
      child: child,
      builder: (context, child) {
        final v = route.value;
        if (v >= 1) return child!;
        if (reduced) return Opacity(opacity: v, child: child);
        final e = _settle.transform(v);
        return Opacity(
          opacity: const Interval(.42, .7).transform(v),
          child: Transform.translate(offset: Offset(0, -64 * (1 - e)), child: child),
        );
      },
    );
  }
}

/// Carries the "a" from Welcome's doorway to its seat on one curve (up, then across), growing smaller and leaning in
/// to listen as it lands. Tied to the route, so Back flies it home.
class _AFlight extends SingleChildRenderObjectWidget {
  const _AFlight({required this.route, required this.from, required super.child});
  final Animation<double> route;
  final AFlightStart? from;

  @override
  _RenderAFlight createRenderObject(BuildContext context) => _RenderAFlight(route, from);

  @override
  void updateRenderObject(BuildContext context, _RenderAFlight renderObject) {
    renderObject
      ..route = route
      ..from = from;
  }
}

class _RenderAFlight extends RenderProxyBox {
  _RenderAFlight(this._route, this.from);

  Animation<double> _route;
  set route(Animation<double> v) {
    if (v == _route) return;
    if (attached) {
      _route.removeListener(markNeedsPaint);
      v.addListener(markNeedsPaint);
    }
    _route = v;
    markNeedsPaint();
  }

  AFlightStart? from;

  /// The bowl's centre in the 100 × 88 "a" box, and the logo scale of that box (bowl radius 45 × 88/124 px).
  static const _bowl = Offset(44.3, 45.4);
  static const _ownScale = 88 / 124;
  static const _curve = Interval(0, .9, curve: Cubic(.45, 0, .12, 1));

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _route.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _route.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final f = from;
    final v = _route.value;
    if (f == null || v >= 1) return super.paint(context, offset);
    final e = _curve.transform(v);
    // in screen terms: from the doorway, rising first and then curving across to the seat
    final here = localToGlobal(_bowl);
    final p0 = f.bowl, p2 = here, p1 = Offset(p0.dx, p2.dy + (p0.dy - p2.dy) * .15);
    final u = 1 - e;
    final at = p0 * (u * u) + p1 * (2 * u * e) + p2 * (e * e);
    final local = globalToLocal(at);
    final unit = (localToGlobal(const Offset(1, 0)) - localToGlobal(Offset.zero)).dx;
    final s0 = f.scale / (_ownScale * unit);
    final s = s0 + (1 - s0) * e;
    final lean = 7 * math.pi / 180 * (1 - e); // upright in the doorway, leaning in to listen at its seat
    final m = Matrix4.identity()
      ..translateByDouble(local.dx, local.dy, 0, 1)
      ..rotateZ(lean)
      ..scaleByDouble(s, s, 1, 1)
      ..translateByDouble(-_bowl.dx, -_bowl.dy, 0, 1);
    context.pushTransform(needsCompositing, offset, m, super.paint);
  }
}

/// "or", with a hairline on each side.
class _Or extends StatelessWidget {
  const _Or();

  @override
  Widget build(BuildContext context) {
    Widget line() => Expanded(child: Container(height: 1.5, color: AdColors.line));
    return Row(
      children: [
        line(),
        const SizedBox(width: 14),
        ExcludeSemantics(child: Text('or', style: KpType.or)),
        const SizedBox(width: 14),
        line(),
      ],
    );
  }
}

/// No network: an ink pill slides down under the toran (GI-12). It floats, so nothing on the page moves.
class _OfflinePill extends StatelessWidget {
  const _OfflinePill({required this.offline, required this.reduced});
  final bool offline;
  final bool reduced;

  @override
  Widget build(BuildContext context) {
    final d = reduced ? const Duration(microseconds: 1) : const Duration(milliseconds: 360);
    return IgnorePointer(
      child: AnimatedSlide(
        duration: d,
        curve: offline ? const Cubic(.3, 1.3, .5, 1) : Curves.easeIn,
        offset: offline ? Offset.zero : const Offset(0, -1.4),
        child: AnimatedOpacity(
          duration: d,
          opacity: offline ? 1 : 0,
          child: Center(
            child: Semantics(
              liveRegion: true,
              child: offline
                  ? Container(
                      padding: const EdgeInsets.fromLTRB(14, 10, 18, 10),
                      decoration: const BoxDecoration(
                        color: AdColors.ink,
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                        boxShadow: [BoxShadow(color: Color(0x331A1410), blurRadius: 18, offset: Offset(0, 6))],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const OfflineMark(size: 20),
                          const SizedBox(width: 10),
                          Flexible(child: Text(GsCopy.offline, style: KpType.offline)),
                        ],
                      ),
                    )
                  : const SizedBox(height: 40),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hidden while the next screen is on its way in (it draws the same thing in the same place).
class _HideWhile extends StatelessWidget {
  const _HideWhile({required this.away, required this.child});
  final Animation<double> away;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: away,
    child: child,
    builder: (context, child) => Opacity(opacity: away.value > 0 ? 0 : 1, child: child),
  );
}

/// Steps aside to the left (and fades) while the next screen comes in; comes back on Back.
class _StepLeft extends StatelessWidget {
  const _StepLeft({required this.away, required this.reduced, required this.child});
  final Animation<double> away;
  final bool reduced;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: away,
    child: child,
    builder: (context, child) {
      final v = away.value;
      if (v == 0) return child!;
      final e = const Interval(0, .4, curve: Curves.easeOutCubic).transform(v);
      return IgnorePointer(
        child: Opacity(
          opacity: 1 - e,
          child: reduced ? child : Transform.translate(offset: Offset(-44 * e, 0), child: child),
        ),
      );
    },
  );
}
