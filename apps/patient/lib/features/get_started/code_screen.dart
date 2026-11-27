import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion/keyframes.dart';
import '../../core/theme/css_paragraph.dart';
import '../../core/theme/tokens.dart';
import '../../shared/headline_fit.dart';
import '../../shared/indian_phone.dart';
import '../../shared/widgets/code_tiles.dart';
import '../../shared/widgets/fill_column.dart';
import '../../shared/widgets/google_button.dart' show GoogleG;
import '../../shared/widgets/kp_icons.dart';
import '../../shared/widgets/phone_field.dart' show DigitSlots;
import '../../shared/widgets/page_moves.dart';
import '../../shared/widgets/primary_button.dart';
import '../launch/launch_store.dart';
import 'code_verifier.dart';
import 'get_started_a.dart';
import 'petals.dart';
import 'phone_code_sender.dart';
import 'toran.dart';

/// Copy on the code screen.
abstract final class CodeCopy {
  static const headline = 'check your\nmessages.';
  static const headlineCompact = 'check your messages.';
  static const sentTo = 'We texted a 6-digit code to';
  static const sentToShort = 'Sent to';
  static const change = 'Change';
  static const checking = 'Checking…';
  static const verified = 'Verified. You’re signed in.';
  static String wrong(int left) =>
      left == 1 ? 'That code didn’t match. 1 try left.' : 'That code didn’t match. $left tries left.';
  static const outOfTries = 'That’s 3 tries. Send a new code to try again.';
  static const expired = 'That code has expired. Send a new one.';
  static const newCode = 'A new code is on its way.';
  static const resend = 'Send a new code';
  static String resendIn(Duration d) {
    final s = math.max(0, d.inSeconds);
    return 'Send a new code in ${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  static const helpTitle = 'Didn’t get it?';
  static const again = 'Send it again';
  static String againIn(Duration d) {
    final s = math.max(1, d.inSeconds);
    return 'In ${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  static String againTo(PhoneOk p) => 'We’ll text +91 ${p.display}';
  static const check = 'Check the number';
  static String checkSub(PhoneOk p) => 'Is +91 ${p.display} right?';
  static const google = 'Use Google instead';
  static const googleSub = 'No code needed';
  static const googleNote = 'Google sign-in isn’t working right now. Use your phone number instead.';
}

/// GS2 · G4 Code: "check your messages."
///
/// You arrive from the phone screen without the page jumping: the toran, the back button and the a stay exactly where
/// they were, the old page slides away, and your number lifts out of its field and flies up into "We texted a 6-digit
/// code to +91 …". Back plays it in reverse and the number flies home. (Reference board:
/// docs/design/kalighat-pop/G03GetStarted/Code*.)
///
/// - Six painted tiles; it checks by itself when the sixth digit lands, once (no button).
/// - Wrong: a red shake, the digits drop out, "That code didn't match. 2 tries left." (our own cap of 3, GI-25).
/// - Supabase answers the same for wrong and expired; a code older than its life is called expired (GI-27).
/// - Too many tries: the server's real wait (GI-26). After 30 s, "Didn't get it?" offers help (GI-28).
/// - Verified: the tiles turn green one by one, the a is happy and marigold petals go up.
/// - The code waits 10 minutes even if the app is closed (GI-29). Back and Change keep the number (GI-30, GI-31).
class CodeScreen extends ConsumerStatefulWidget {
  const CodeScreen({super.key, required this.arrival, this.onBack, this.onChange, this.onVerified});

  final CodeArrival arrival;

  /// Back to the phone screen with the number kept (GI-30).
  final VoidCallback? onBack;

  /// Change the number: back to the phone screen, ready to edit; this code is forgotten (GI-31).
  final VoidCallback? onChange;

  /// Signed in: called once the celebration has played, with this screen's clock, so About you carries the a and the
  /// toran on without a jump.
  final ValueChanged<double>? onVerified;

  @override
  ConsumerState<CodeScreen> createState() => _CodeScreenState();
}

enum _Note { none, help, bad, good, checking }

class _CodeScreenState extends ConsumerState<CodeScreen> with SingleTickerProviderStateMixin {
  final _code = TextEditingController();
  final _focus = FocusNode();
  late final _clock = ValueNotifier<double>(widget.arrival.clockFrom);
  final _scroll = ScrollController();
  final _pageKey = GlobalKey();
  final _tilesKey = GlobalKey();
  final _noteKey = GlobalKey();
  final _pillSlotsKey = GlobalKey();
  late final Ticker _ticker = createTicker((e) => _clock.value = widget.arrival.clockFrom + e.inMicroseconds / 1e6);
  Timer? _second;
  Timer? _settle;
  Timer? _unwrong;
  Timer? _visible;
  Timer? _leave;

  late DateTime _sentAt = widget.arrival.sentAt;
  late int _sends = widget.arrival.sends;
  CodeLook _look = CodeLook.typing;
  int _wrongCount = 0;
  int _triesUsed = 0;
  String? _note;
  _Note _noteKind = _Note.none;
  DateTime? _waitUntil;
  bool _resending = false;
  bool _googleNote = false;
  double? _petalsAt;
  GsMood _mood = GsMood.happy; // as it was on the phone screen; it settles into listening
  bool _focusedOnce = false;
  double? _regularBottom;
  double _lastKeyboard = 0;

  PhoneOk get _phone => widget.arrival.phone;

  @override
  void initState() {
    super.initState();
    _second = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _settle = Timer(const Duration(milliseconds: 450), () {
      if (mounted && _mood == GsMood.happy && _look == CodeLook.typing) setState(() => _mood = GsMood.listening);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced && _ticker.isActive) _ticker.stop();
    if (!reduced && !_ticker.isActive) _ticker.start();
    // the keyboard comes up once the move from the phone screen has finished
    final route = ModalRoute.of(context)?.animation;
    if (route != _routeAnimation) {
      _routeAnimation?.removeStatusListener(_routeStatus);
      _routeAnimation = route;
      if (route == null || route.isCompleted) {
        _focusSoon();
      } else {
        route.addStatusListener(_routeStatus);
      }
    }
  }

  Animation<double>? _routeAnimation;

  void _routeStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed) _focusSoon();
  }

  void _focusSoon() {
    if (_focusedOnce) return;
    _focusedOnce = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted && _look == CodeLook.typing) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_routeStatus);
    _ticker.dispose();
    _second?.cancel();
    _settle?.cancel();
    _unwrong?.cancel();
    _visible?.cancel();
    _leave?.cancel();
    _code.dispose();
    _focus.dispose();
    _clock.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ---- time ---------------------------------------------------------------------------------

  Duration get _sinceSent => clock.now().difference(_sentAt);
  Duration get _untilResend => CodeRules.resendAfter(_sends) - _sinceSent;
  bool get _waiting => _waitUntil != null && clock.now().isBefore(_waitUntil!);
  bool get _canResend => !_resending && !_waiting && _untilResend <= Duration.zero && _look != CodeLook.verified;

  void _remember(PendingCode? p) => ref.read(launchStoreProvider).setPendingCode(p);

  // ---- checking -------------------------------------------------------------------------------

  Future<void> _check(String code) async {
    if (_look != CodeLook.typing) return;
    setState(() {
      _look = CodeLook.checking;
      _mood = GsMood.thinking;
      _note = CodeCopy.checking;
      _noteKind = _Note.checking;
    });
    final result = await ref.read(codeVerifierProvider).verify(_phone, code);
    if (!mounted) return;
    switch (result) {
      case Verified():
        setState(() {
          _look = CodeLook.verified;
          _mood = GsMood.celebrating;
          _note = CodeCopy.verified;
          _noteKind = _Note.good;
          _petalsAt = _clock.value + .3;
        });
        _focus.unfocus();
        _remember(null);
        // the a jumps for joy and the petals fly, then About you takes over
        final reduced = MediaQuery.disableAnimationsOf(context);
        _leave = Timer(Duration(milliseconds: reduced ? 900 : 1600), () {
          if (mounted) widget.onVerified?.call(_clock.value);
        });
      case VerifyRejected():
        if (_sinceSent > CodeRules.life) {
          setState(() {
            _look = CodeLook.locked;
            _mood = GsMood.worried;
            _note = CodeCopy.expired;
            _noteKind = _Note.bad;
          });
          _focus.unfocus();
          return;
        }
        _triesUsed++;
        final left = CodeRules.tries - _triesUsed;
        setState(() {
          _mood = GsMood.worried;
          _wrongCount++;
          _look = left <= 0 ? CodeLook.locked : CodeLook.wrong;
          _note = left <= 0 ? CodeCopy.outOfTries : CodeCopy.wrong(left);
          _noteKind = _Note.bad;
        });
        if (left <= 0) {
          _focus.unfocus();
          return;
        }
        _unwrong?.cancel();
        _unwrong = Timer(const Duration(milliseconds: 900), () {
          if (mounted && _look == CodeLook.wrong) {
            setState(() {
              _look = CodeLook.typing;
              _mood = GsMood.listening;
            });
          }
        });
      case VerifyWait(:final wait):
        setState(() {
          _look = CodeLook.locked;
          _mood = GsMood.worried;
          _waitUntil = wait == null ? null : clock.now().add(wait);
          _note = wait == null ? SendCopy.tooManyLater : null;
          _noteKind = _Note.bad;
        });
        _focus.unfocus();
      case VerifyFailed(:final message):
        setState(() {
          _look = CodeLook.typing;
          _mood = GsMood.worried;
          _note = message;
          _noteKind = _Note.bad;
        });
        _code.clear();
    }
  }

  // ---- a new code ---------------------------------------------------------------------------------

  Future<void> _resend() async {
    if (!_canResend && !(_look == CodeLook.locked && !_waiting && !_resending)) return;
    setState(() => _resending = true);
    final result = await ref.read(phoneCodeSenderProvider).send(_phone);
    if (!mounted) return;
    setState(() {
      _resending = false;
      switch (result) {
        case CodeSent():
          _sentAt = clock.now();
          _sends++;
          _triesUsed = 0;
          _look = CodeLook.typing;
          _mood = GsMood.listening;
          _note = CodeCopy.newCode;
          _noteKind = _Note.help;
          _waitUntil = null;
          _code.clear();
          _remember(PendingCode(e164: _phone.e164, sentAt: _sentAt, sends: _sends));
        case SendWait(:final wait):
          _waitUntil = wait == null ? null : clock.now().add(wait);
          _note = wait == null ? SendCopy.tooManyLater : null;
          _noteKind = _Note.bad;
        case SendFailed(:final message):
          _note = message;
          _noteKind = _Note.bad;
      }
    });
    if (result is CodeSent) _focus.requestFocus();
  }

  void _change() {
    _remember(null);
    final f = widget.onChange;
    if (f != null) return f();
    Navigator.of(context).maybePop('change');
  }

  void _back() {
    final f = widget.onBack;
    if (f != null) return f();
    Navigator.of(context).maybePop();
  }

  // ---- the line under the tiles -------------------------------------------------------------------

  (String?, _Note) get _line {
    final until = _waitUntil;
    if (until != null && clock.now().isBefore(until)) {
      return (SendCopy.tooMany(until.difference(clock.now()) + const Duration(milliseconds: 999)), _Note.bad);
    }
    if (_googleNote) return (CodeCopy.googleNote, _Note.help);
    return (_note, _noteKind);
  }

  // ---- after layout: the keyboard (GI-63) -------------------------------------------------------------

  void _afterLayout(double keyboard, bool compact, double viewport) {
    final page = _pageKey.currentContext?.findRenderObject() as RenderBox?;
    final note = _noteKey.currentContext?.findRenderObject() as RenderBox?;
    if (page == null || note == null || !page.attached) return;
    final bottom = note.localToGlobal(Offset(0, note.size.height), ancestor: page).dy;
    if (!compact && keyboard == 0) {
      _regularBottom = bottom;
    } else if (!compact && _regularBottom == null) {
      setState(() => _regularBottom = bottom);
      return;
    }
    if (keyboard > 0 && keyboard != _lastKeyboard) {
      _visible?.cancel();
      _visible = Timer(const Duration(milliseconds: 360), _keepTilesVisible);
    }
    _lastKeyboard = keyboard;
  }

  void _keepTilesVisible() {
    if (!mounted || !_scroll.hasClients) return;
    final page = _pageKey.currentContext?.findRenderObject() as RenderBox?;
    final note = _noteKey.currentContext?.findRenderObject() as RenderBox?;
    final tiles = _tilesKey.currentContext?.findRenderObject() as RenderBox?;
    if (page == null || note == null || tiles == null) return;
    final mq = MediaQuery.of(context);
    final viewport = mq.size.height - mq.viewInsets.bottom;
    final bottom = note.localToGlobal(Offset(0, note.size.height), ancestor: page).dy;
    final top = tiles.localToGlobal(Offset.zero, ancestor: page).dy;
    final want = math.min(bottom + 12 - viewport, top - 8);
    if (want > _scroll.offset) _scroll.jumpTo(want.clamp(0.0, _scroll.position.maxScrollExtent));
  }

  // ---- layout ---------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final reduced = mq.disableAnimations;
    final width = mq.size.width;
    final height = mq.size.height;
    final safeTop = mq.padding.top;
    final keyboard = mq.viewInsets.bottom;
    final viewport = height - keyboard;
    final regular = _regularBottom;
    final compact = keyboard > 0 && regular != null && viewport < regular + 16;
    // with large text the a moves up into the top bar, so the headline has the whole width (GI-60)
    final aInBar = compact || mq.textScaler.scale(10) / 10 > 1.3;
    final route = ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation;
    final move = reduced ? const Duration(microseconds: 1) : const Duration(milliseconds: 320);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _afterLayout(keyboard, compact, viewport);
    });

    Widget slideIn(double start, Widget child) =>
        reduced ? FadeTransition(opacity: route, child: child) : SlideIn(route: route, start: start, child: child);

    // the headline fits beside the a (46 px where it can, smaller on narrow phones)
    final heroWidth = width - 2 * AdSpace.side - (aInBar ? 0 : 102);
    final h1 = HeadlineFit.fitted(KpType.h1(), 'check your', width - 2 * AdSpace.side - 102);
    // the headline grows with the text size only until its longest word fills the line, so no word ever breaks
    final h1Grow = HeadlineFit.grow(h1, 'messages.', heroWidth);
    final h1CompactGrow = HeadlineFit.grow(
      HeadlineFit.fitted(KpType.h1(compact: true), CodeCopy.headlineCompact, width - 48),
      'messages.',
      width - 2 * AdSpace.side,
    );
    final h1Compact = HeadlineFit.fitted(KpType.h1(compact: true), CodeCopy.headlineCompact, width - 2 * AdSpace.side);

    final pill = _NumberPill(
      phone: _phone,
      slotsKey: _pillSlotsKey,
      route: route,
      flying: widget.arrival.numberFrom != null && !reduced,
      onTap: _look == CodeLook.verified || _look == CodeLook.checking ? null : _change,
    );

    final (line, lineKind) = _line;
    final showHelpCard = _look == CodeLook.typing && _sinceSent >= CodeRules.helpAfter && !_resending;
    final needNewCode = _look == CodeLook.locked && !_waiting && _waitUntil == null || _note == CodeCopy.expired;

    final top = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          key: const ValueKey('top'),
          duration: move,
          curve: Curves.easeInOutCubic,
          height: 40 + (aInBar ? 56 : 48),
          alignment: Alignment.bottomLeft,
          child: SizedBox(
            height: aInBar ? 56 : 48,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Transform.translate(
                offset: const Offset(-12, 0),
                child: KpBackButton(onTap: _back, label: 'Back to your number'),
              ),
            ),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        header: true,
                        child: MediaQuery.withClampedTextScaling(
                          maxScaleFactor: h1CompactGrow,
                          child: CssParagraph(CodeCopy.headlineCompact, style: h1Compact),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          Text(CodeCopy.sentToShort, style: AdType.lede(compact: true)),
                          pill,
                        ],
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: aInBar ? 16 : 44),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: slideIn(
                              .24,
                              Semantics(
                                header: true,
                                child: MediaQuery.withClampedTextScaling(
                                  maxScaleFactor: h1Grow,
                                  child: CssParagraph(CodeCopy.headline, style: h1),
                                ),
                              ),
                            ),
                          ),
                          if (!aInBar) const SizedBox(width: 102, height: 92),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: slideIn(
                        .32,
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(CodeCopy.sentTo, style: AdType.lede()),
                            const SizedBox(height: 10),
                            pill,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        AnimatedPadding(
          key: const ValueKey('tiles'),
          duration: move,
          curve: Curves.easeInOutCubic,
          padding: EdgeInsets.only(top: compact ? 16 : 28),
          child: slideIn(
            .4,
            KeyedSubtree(
              key: _tilesKey,
              child: CodeTiles(
                controller: _code,
                focusNode: _focus,
                look: _look,
                wrongCount: _wrongCount,
                onCompleted: _check,
                holdScroll: true,
              ),
            ),
          ),
        ),
        KeyedSubtree(
          key: _noteKey,
          child: _NoteLine(text: line, kind: lineKind, reduced: reduced),
        ),
        slideIn(
          .48,
          AnimatedSize(
            key: const ValueKey('after'),
            duration: move,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: needNewCode
                ? Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: PrimaryButton(
                      label: CodeCopy.resend,
                      busyLabel: 'Sending code',
                      loading: _resending,
                      onPressed: _waiting ? null : _resend,
                    ),
                  )
                : showHelpCard
                ? Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: _HelpCard(
                      phone: _phone,
                      canResend: _canResend,
                      untilResend: _untilResend,
                      onResend: _resend,
                      onCheck: _change,
                      onGoogle: () => setState(() => _googleNote = true),
                    ),
                  )
                : _look == CodeLook.verified
                ? const SizedBox(width: double.infinity)
                : _ResendLine(
                    canResend: _canResend,
                    resending: _resending,
                    untilResend: _untilResend,
                    onResend: _resend,
                  ),
          ),
        ),
      ],
    );

    // when About you comes in on top, the toran and the a stay put there (it draws its own) and the rest steps aside
    final away = ModalRoute.of(context)?.secondaryAnimation ?? kAlwaysDismissedAnimation;

    // the a, in the same seat as on the phone screen (or up in the top bar on a short phone with the keyboard open)
    final aScale = aInBar ? .56 : 1.0;
    final a = AnimatedPositioned(
      duration: move,
      curve: Curves.easeInOutCubic,
      left: aInBar ? width - AdSpace.side - 100 * aScale + 4 : width - AdSpace.side - 100 + 6,
      top: aInBar ? safeTop + 40 + 3 : safeTop + 132,
      child: AnimatedScale(
        duration: move,
        curve: Curves.easeInOutCubic,
        alignment: Alignment.topLeft,
        scale: aScale,
        child: HideWhile(
          away: away,
          child: GetStartedA(time: _clock, mood: _mood, digits: _code.text.length * 10 ~/ 6, reduced: reduced),
        ),
      ),
    );

    final page = Stack(
      children: [
        Positioned(
          top: safeTop,
          left: 0,
          right: 0,
          child: HideWhile(
            away: away,
            child: Toran(time: _clock, reduced: reduced),
          ),
        ),
        StepLeft(
          away: away,
          reduced: reduced,
          child: FillColumn(
            key: _pageKey,
            minHeight: height,
            top: Padding(padding: EdgeInsets.fromLTRB(AdSpace.side, safeTop, AdSpace.side, 0), child: top),
            bottom: SizedBox(height: math.max(24, mq.padding.bottom)),
          ),
        ),
        a,
        Positioned.fill(
          child: StepLeft(
            away: away,
            reduced: reduced,
            child: _PetalLayer(time: _clock, firedAt: _petalsAt, tilesKey: _tilesKey, reduced: reduced),
          ),
        ),
        if (widget.arrival.numberFrom != null && !reduced)
          Positioned.fill(
            child: IgnorePointer(
              child: _NumberFlight(
                route: route,
                from: widget.arrival.numberFrom!,
                targetKey: _pillSlotsKey,
                child: DigitSlots.still(digits: _phone.national),
              ),
            ),
          ),
      ],
    );

    return Stack(
      children: [
        // the phone screen's paper shows through while the page changes; this one takes over at the end
        Positioned.fill(
          child: FadeTransition(
            opacity: CurvedAnimation(parent: route, curve: const Interval(.9, 1)),
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

/// "+91 98765 43210 · Change": the number the code went to, as a pill you can tap to change it.
class _NumberPill extends StatelessWidget {
  const _NumberPill({
    required this.phone,
    required this.slotsKey,
    required this.route,
    required this.flying,
    required this.onTap,
  });
  final PhoneOk phone;
  final GlobalKey slotsKey;
  final Animation<double> route;
  final bool flying;
  final VoidCallback? onTap;

  static const slotsScale = .68;

  @override
  Widget build(BuildContext context) {
    final slots = KeyedSubtree(
      key: slotsKey,
      child: MediaQuery.withNoTextScaling(
        child: DigitSlots.still(digits: phone.national, scaler: const TextScaler.linear(slotsScale)),
      ),
    );
    return Semantics(
      button: onTap != null,
      label: 'Change number, plus 91 ${phone.display}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.fromLTRB(16, 6, 14, 6),
          decoration: BoxDecoration(
            color: AdColors.white,
            borderRadius: const BorderRadius.all(Radius.circular(22)),
            border: Border.all(color: AdColors.fieldBorder, width: 1.5),
          ),
          // when it can't fit on one line (large text, a narrow phone), "Change" moves under the number
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 14,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('+91', style: KpType.pillNumber),
                  const SizedBox(width: 8),
                  // while the number is flying in, its place waits empty
                  if (flying)
                    AnimatedBuilder(
                      animation: route,
                      child: slots,
                      builder: (context, child) => Opacity(opacity: route.value >= 1 ? 1 : 0, child: child),
                    )
                  else
                    slots,
                ],
              ),
              if (onTap != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const PencilMark(size: 15),
                    const SizedBox(width: 4),
                    Text(CodeCopy.change, style: KpType.pillAction),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The phone number flying from the phone screen's field into the pill, on a gentle arc, shrinking as it goes.
/// Tied to the route, so Back flies it home.
class _NumberFlight extends SingleChildRenderObjectWidget {
  const _NumberFlight({required this.route, required this.from, required this.targetKey, required super.child});
  final Animation<double> route;
  final Rect from;
  final GlobalKey targetKey;

  @override
  _RenderNumberFlight createRenderObject(BuildContext context) => _RenderNumberFlight(route, from, targetKey);

  @override
  void updateRenderObject(BuildContext context, _RenderNumberFlight renderObject) {
    renderObject
      ..route = route
      ..from = from
      ..targetKey = targetKey;
  }
}

class _RenderNumberFlight extends RenderProxyBox {
  _RenderNumberFlight(this._route, this.from, this.targetKey);

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

  Rect from;
  GlobalKey targetKey;

  static const _curve = Interval(.04, .82, curve: Cubic(.45, 0, .15, 1));

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
  void performLayout() {
    child!.layout(const BoxConstraints(), parentUsesSize: true);
    size = constraints.biggest;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => false;

  @override
  void paint(PaintingContext context, Offset offset) {
    final v = _route.value;
    final target = targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (v >= 1 || child == null || target == null || !target.attached || !target.hasSize) return;
    final e = _curve.transform(v);
    final to = target.localToGlobal(Offset.zero) & target.size;
    final own = child!.size;
    final s0 = from.height / own.height, s1 = to.height / own.height;
    final s = s0 + (s1 - s0) * e;
    // a gentle arc: up first, then across
    final p0 = from.topLeft, p2 = to.topLeft, p1 = Offset(p0.dx, p2.dy + (p0.dy - p2.dy) * .3);
    final u = 1 - e;
    final at = globalToLocal(p0 * (u * u) + p1 * (2 * u * e) + p2 * (e * e));
    context.pushTransform(
      needsCompositing,
      offset,
      Matrix4.identity()
        ..translateByDouble(at.dx, at.dy, 0, 1)
        ..scaleByDouble(s, s, 1, 1),
      (c, o) => c.paintChild(child!, o),
    );
  }
}

/// The line under the tiles: checking (three breathing dots), a problem (the alert mark), good news (a tick), or help.
class _NoteLine extends StatelessWidget {
  const _NoteLine({required this.text, required this.kind, required this.reduced});
  final String? text;
  final _Note kind;
  final bool reduced;

  @override
  Widget build(BuildContext context) {
    final t = text;
    final quick = reduced ? const Duration(microseconds: 1) : const Duration(milliseconds: 180);
    final style = switch (kind) {
      _Note.bad => KpType.helpBad,
      _Note.good => KpType.helpGood,
      _ => KpType.help,
    };
    return AnimatedSize(
      duration: quick,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topLeft,
      child: AnimatedSwitcher(
        duration: quick,
        layoutBuilder: (current, previous) => Stack(alignment: Alignment.topLeft, children: [...previous, ?current]),
        child: t == null || t.isEmpty
            ? const SizedBox(key: ValueKey(''), width: double.infinity, height: 12)
            : Padding(
                key: ValueKey('$kind$t'),
                padding: const EdgeInsets.only(top: 14),
                child: Semantics(
                  liveRegion: true,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2, right: 8),
                        child: switch (kind) {
                          _Note.bad => const AlertMark(size: 18),
                          _Note.good => const TickMark(size: 18),
                          _Note.checking => const _ThreeDots(),
                          _ => const SizedBox.shrink(),
                        },
                      ),
                      Expanded(child: CssParagraph(t, style: style)),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

/// Three muted dots breathing one after another (checking).
class _ThreeDots extends StatefulWidget {
  const _ThreeDots();

  @override
  State<_ThreeDots> createState() => _ThreeDotsState();
}

class _ThreeDotsState extends State<_ThreeDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static final _kDot = Keyframes.of(const [(0, .25), (.5, 1), (1, .25)]);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 18,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(painter: _DotsPainter(_c.isAnimating ? _c.value : .5, _kDot)),
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  _DotsPainter(this.v, this.frames);
  final double v;
  final Keyframes frames;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 3; i++) {
      final p = (v - i * .16) % 1;
      final a = frames.at(p, 0, cssEaseInOut);
      canvas.drawCircle(
        Offset(4 + i * 9.0, size.height / 2),
        3.2,
        Paint()..color = AdColors.muted.withValues(alpha: a),
      );
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.v != v;
}

/// "Send a new code in 0:42", then a small pill to send it.
class _ResendLine extends StatelessWidget {
  const _ResendLine({
    required this.canResend,
    required this.resending,
    required this.untilResend,
    required this.onResend,
  });
  final bool canResend;
  final bool resending;
  final Duration untilResend;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Align(
        alignment: Alignment.centerLeft,
        child: canResend || resending
            ? Semantics(
                button: true,
                label: CodeCopy.resend,
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: resending ? null : onResend,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(Radius.circular(999)),
                      border: Border.all(color: AdColors.ink, width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const RefreshMark(size: 18),
                        const SizedBox(width: 8),
                        Text(resending ? 'Sending…' : CodeCopy.resend, style: KpType.rowTitle),
                      ],
                    ),
                  ),
                ),
              )
            : ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: 1,
                  child: Text(
                    CodeCopy.resendIn(untilResend + const Duration(milliseconds: 999)),
                    style: KpType.help.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                ),
              ),
      ),
    );
  }
}

/// "Didn't get it?": send it again (when the server allows), check the number, or use Google (GI-28).
class _HelpCard extends StatelessWidget {
  const _HelpCard({
    required this.phone,
    required this.canResend,
    required this.untilResend,
    required this.onResend,
    required this.onCheck,
    required this.onGoogle,
  });
  final PhoneOk phone;
  final bool canResend;
  final Duration untilResend;
  final VoidCallback onResend;
  final VoidCallback onCheck;
  final VoidCallback onGoogle;

  @override
  Widget build(BuildContext context) {
    Widget row(Widget icon, String title, String sub, VoidCallback? onTap, {bool first = false}) => Semantics(
      button: true,
      enabled: onTap != null,
      label: '$title. $sub',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: first
              ? null
              : const BoxDecoration(
                  border: Border(top: BorderSide(color: AdColors.line, width: 1.5)),
                ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AdColors.paper, shape: BoxShape.circle),
                child: Opacity(opacity: onTap == null ? .45 : 1, child: icon),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: KpType.rowTitle.copyWith(color: onTap == null ? AdColors.muted : AdColors.ink)),
                    const SizedBox(height: 2),
                    Text(sub, style: KpType.rowSub.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                  ],
                ),
              ),
              if (onTap != null) const ChevronMark(),
            ],
          ),
        ),
      ),
    );

    return _Rise(
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
        decoration: const BoxDecoration(
          color: AdColors.white,
          borderRadius: BorderRadius.all(Radius.circular(24)),
          boxShadow: [BoxShadow(color: Color(0x0F1A1410), blurRadius: 24, offset: Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Text(CodeCopy.helpTitle, style: KpType.cardTitle),
            ),
            row(
              const RefreshMark(),
              CodeCopy.again,
              canResend ? CodeCopy.againTo(phone) : CodeCopy.againIn(untilResend + const Duration(milliseconds: 999)),
              canResend ? onResend : null,
              first: true,
            ),
            row(const PhoneMark(), CodeCopy.check, CodeCopy.checkSub(phone), onCheck),
            row(
              const SizedBox(width: 20, height: 20, child: CustomPaint(painter: GoogleG())),
              CodeCopy.google,
              CodeCopy.googleSub,
              onGoogle,
            ),
          ],
        ),
      ),
    );
  }
}

/// A short rise into place when something appears.
class _Rise extends StatelessWidget {
  const _Rise({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, e, child) => Opacity(
        opacity: e,
        child: Transform.translate(offset: Offset(0, 14 * (1 - e)), child: child),
      ),
    );
  }
}

/// Throws the petals from just above the tiles' middle.
class _PetalLayer extends StatelessWidget {
  const _PetalLayer({required this.time, required this.firedAt, required this.tilesKey, required this.reduced});
  final ValueListenable<double> time;
  final double? firedAt;
  final GlobalKey tilesKey;
  final bool reduced;

  @override
  Widget build(BuildContext context) {
    if (firedAt == null || reduced) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, box) {
        final tiles = tilesKey.currentContext?.findRenderObject() as RenderBox?;
        final me = context.findRenderObject() as RenderBox?;
        var origin = Offset(box.maxWidth / 2, 360);
        if (tiles != null && me != null && tiles.attached && me.attached) {
          origin = me.globalToLocal(tiles.localToGlobal(Offset(tiles.size.width / 2, 8)));
        }
        return PetalBurst(time: time, firedAt: firedAt, origin: origin);
      },
    );
  }
}
