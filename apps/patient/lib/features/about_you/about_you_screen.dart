import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/css_paragraph.dart';
import '../../core/theme/tokens.dart';
import '../../shared/headline_fit.dart';
import '../../shared/widgets/fill_column.dart';
import '../../shared/widgets/kp_icons.dart';
import '../../shared/widgets/page_moves.dart';
import '../../shared/widgets/primary_button.dart';
import '../get_started/get_started_a.dart';
import '../get_started/petals.dart';
import '../get_started/toran.dart';
import '../launch/launch_store.dart';
import 'about_you_parts.dart';
import 'age_dial.dart';
import 'basics.dart';
import 'birth_wheel.dart';
import 'helpline.dart';

/// The steps of About you, and See you at 13.
enum AboutStep { name, birth, age, gender, done, tooYoung }

/// Copy on About you (sentence case; headlines lowercase, as on Welcome).
abstract final class AboutCopy {
  static const nameHeadline = 'what should\nwe call you?';
  static const nameHeadlineCompact = 'what should we call you?';
  static const first = 'First name';
  static const firstHint = 'Priya';
  static const last = 'Last name';
  static const lastHint = 'Shah';
  static const optional = 'optional';
  static const nameBad = 'Just letters, please. Names don’t have numbers or symbols.';
  static const hello = 'namaste!';

  static const birthHeadline = 'when were\nyou born?';
  static const birthWhy = 'Doctors need your age. We never show it to anyone else.';
  static String makesYou(int n) => 'That makes you $n.';
  static const future = 'That date hasn’t happened yet.';
  static const thisYear = 'That’s this year. Pick the year you were born.';
  static const onlyAge = 'Only know your age?';

  static const ageHeadline = 'about how\nold are you?';
  static const ageWhy = 'No birth certificate? Totally normal. A close number is enough.';
  static String estimate(int n) => 'Doctors will see “about $n”, so they know it’s an estimate.';
  static const adultsOnly = 'Under 18, we need the birth month and year.';
  static const under18 = 'For anyone under 18 we need the birth month and year, so we can follow the law on consent.';
  static const exact = 'I know my birth month and year';

  static String confirmBirth(int month, int year) => 'born in\n${monthNames[month - 1]} $year?';
  static String confirmAge(int age) => 'about $age?';
  static const confirmWhy =
      'You can’t change this later, so every doctor sees the right age. If it’s wrong, our support team can fix it.';
  static String over100(int age) => 'That makes you $age. ';
  static const yes = 'Yes, that’s right';
  static const change = 'Change it';
  static const checking = 'Checking';

  static const genderHeadline = 'which fits\nyou best?';
  static const genderWhy =
      'Some care depends on it, like which tests a doctor suggests. Only you and your doctors see it. You can change it any time.';

  static const next = 'Continue';
  static const saving = 'Saving';
  static const slow = 'This is taking longer than usual.';
  static const locked = 'Your birth date is already saved, so it can’t change here. Our support team can fix it.';

  static const nice = 'nice to meet you, ';
  static const nextAdult = 'Next: how we look after your health data.';
  static String nextTeen(int age) =>
      'You’re $age, so next a parent says yes before you see doctors or order medicines.';
  static const born = 'Born';
  static const age = 'Age';
  static const gender = 'Gender';

  static const seeYouHeadline = 'see you\nat 13.';
  static const seeYouBody =
      'ApneDoctors is for people 13 and up. Until then, a parent can add you to their family here and book care for you.';
}

/// GS3 · G7 About you: your name, when you were born (or, for adults, just your age), and which fits you best.
///
/// The a hosts it. You arrive from the code screen with the a still in its seat; it greets you in a speech bubble
/// ("namaste!") that says your name back as you type it. Each step slides in beside the still a and toran; the step
/// dots grow. The month and year roll on a wheel with a vermilion band, the age line under it says how old that makes
/// you, and before anything is kept the a hops down onto a sheet that asks "born in March 2004?" (you can't change it
/// later, GI-42). An age on its own is only for adults (GI-46). The chosen answer gets a painted dot border. Saved:
/// "nice to meet you, Priya!", petals, and a card of what you told us.
///
/// - Everything is saved at once by `public.set_basics`, which checks every rule again and counts the age in IST.
/// - Under 13: See you at 13 with Childline 1098. Only the birth date is sent; nothing is kept; the account waits 24 h
///   and this phone 7 days (GI-41). It never says which year would pass.
/// - What you type is kept on the phone until it's saved, so closing the app loses nothing (GI-05, GI-64).
/// - Continue sits in one place at the bottom for every step, above the keyboard when it's open (GI-63).
class AboutYouScreen extends ConsumerStatefulWidget {
  const AboutYouScreen({super.key, this.clockFrom = 0, this.draft, this.start, this.onDone});

  /// The code screen's clock when it handed over, so the a and toran carry on without a jump.
  final double clockFrom;

  /// What was typed before the app was closed.
  final BasicsDraft? draft;

  /// Where to open (See you at 13 at launch, GI-16). Default: the draft's step, or the name.
  final AboutStep? start;

  /// Saved; the next onboarding step follows (Your data, or a parent's yes for a teen).
  final ValueChanged<Saved>? onDone;

  @override
  ConsumerState<AboutYouScreen> createState() => _AboutYouScreenState();
}

class _AboutYouScreenState extends ConsumerState<AboutYouScreen> with TickerProviderStateMixin {
  late final _clock = ValueNotifier<double>(widget.clockFrom);
  late final Ticker _ticker = createTicker((e) => _clock.value = widget.clockFrom + e.inMicroseconds / 1e6);
  late final _stepAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  late final _sheet = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
    reverseDuration: const Duration(milliseconds: 300),
  );
  final _scroll = ScrollController();
  late final Listenable _flightRepaint = Listenable.merge([_clock, _scroll, _sheet]);
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _firstFocus = FocusNode();
  final _lastFocus = FocusNode();
  final _pageKey = GlobalKey();
  final _seatKey = GlobalKey();
  final _slotKey = GlobalKey();
  final _dockKey = GlobalKey();
  final _lastFieldKey = GlobalKey();
  final _firstFieldKey = GlobalKey();

  late AboutStep _step;
  AboutStep? _leaving;
  bool _forward = true;

  late final DateTime _today = istToday(clock.now());
  int _month = 3;
  late int _year = _today.year - 22;
  bool _ageOnly = false;
  int _age = 30;
  Gender? _gender;
  bool _over100Confirmed = false;

  bool _sheetOpen = false;
  bool _checking = false; // the under-13 check, from the sheet
  bool _saving = false;
  bool _slow = false;
  String? _note; // a problem, above Continue or on the sheet
  bool _belowMin = false; // GI-46
  String? _birthNote; // the server turned the birth date down (GI-42, GI-46)
  bool _cheer = false; // a short happy beat (the a hops)
  Saved? _saved;
  double? _petalsAt;

  double? _regularBottom;
  double _dockHeight = 86;
  double _lastKeyboard = 0;
  bool _focusedOnce = false;
  Animation<double>? _routeAnimation;

  Timer? _cheerTimer;
  Timer? _settle;
  Timer? _slowTimer;
  Timer? _draftTimer;
  Timer? _visible;

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    if (d != null) {
      _first.text = d.first;
      _last.text = d.last;
      if (d.month != null) _month = d.month!.clamp(1, 12);
      if (d.year != null) _year = d.year!.clamp(_today.year - AgeRules.oldest, _today.year);
      _ageOnly = d.ageOnly;
      if (d.age != null) _age = d.age!.clamp(AgeRules.estimateFrom, AgeRules.oldest);
      _gender = d.gender;
    }
    _step =
        widget.start ??
        switch (d?.step) {
          'birth' when NameRules.ok(_first.text) => AboutStep.birth,
          'age' when NameRules.ok(_first.text) => AboutStep.age,
          'gender' when NameRules.ok(_first.text) => _ageOnly ? AboutStep.age : AboutStep.birth,
          _ => AboutStep.name,
        };
    _wasNamed = NameRules.ok(_first.text);
    _first.addListener(_typed);
    _last.addListener(_typed);
    // arriving, the a is still happy from the code; it settles into listening
    _cheer = _step == AboutStep.name;
    _settle = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _cheer = false);
    });
    if (_step == AboutStep.done) _petalsAt = widget.clockFrom + .2;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced && _ticker.isActive) _ticker.stop();
    if (!reduced && !_ticker.isActive) _ticker.start();
    final quick = reduced ? const Duration(microseconds: 1) : null;
    _stepAnim.duration = quick ?? const Duration(milliseconds: 600);
    _sheet.duration = quick ?? const Duration(milliseconds: 460);
    _sheet.reverseDuration = quick ?? const Duration(milliseconds: 300);
    // the keyboard comes up once the move from the code screen has finished
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

  void _routeStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed) _focusSoon();
  }

  void _focusSoon() {
    if (_focusedOnce) return;
    _focusedOnce = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted && _step == AboutStep.name && !NameRules.ok(_first.text)) _firstFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_routeStatus);
    _ticker.dispose();
    _stepAnim.dispose();
    _sheet.dispose();
    for (final t in [_cheerTimer, _settle, _slowTimer, _draftTimer, _visible]) {
      t?.cancel();
    }
    _first.dispose();
    _last.dispose();
    _firstFocus.dispose();
    _lastFocus.dispose();
    _scroll.dispose();
    _clock.dispose();
    super.dispose();
  }

  // ---- what they told us ----------------------------------------------------------------------------

  Birth get _birth => _ageOnly ? AgeOnly(_age) : BirthMonth(_year, _month);
  int get _years => ageFrom(_birth, _today);
  BirthCheck get _birthCheck => checkBirth(BirthMonth(_year, _month), _today);
  bool get _nameReady => NameRules.ok(_first.text) && !NameRules.bad(_last.text);

  bool _wasNamed = false;

  void _typed() {
    final named = NameRules.ok(_first.text);
    if (named && !_wasNamed) _hop(); // the a is happy to hear your name
    _wasNamed = named;
    if (mounted) setState(() {});
    _keepDraft();
  }

  void _hop() {
    _cheerTimer?.cancel();
    setState(() => _cheer = true);
    _cheerTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _cheer = false);
    });
  }

  void _keepDraft() {
    if (_step == AboutStep.done || _step == AboutStep.tooYoung) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 250), () {
      // saved, or under 13, since this was scheduled: nothing is kept
      if (!mounted || _step == AboutStep.done || _step == AboutStep.tooYoung) return;
      ref
          .read(launchStoreProvider)
          .setBasicsDraft(
            BasicsDraft(
              step: _step.name,
              first: _first.text,
              last: _last.text,
              month: _month,
              year: _year,
              ageOnly: _ageOnly,
              age: _age,
              gender: _gender,
            ).toJson(),
          );
    });
  }

  // ---- moving between steps -------------------------------------------------------------------------

  int _moves = 0;

  void _go(AboutStep next, {bool forward = true}) {
    if (next == _step) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final move = ++_moves;
    setState(() {
      _leaving = _step;
      _step = next;
      _forward = forward;
      _note = null;
      _scrollTop();
    });
    _stepAnim.forward(from: 0).whenCompleteOrCancel(() {
      if (mounted && move == _moves) setState(() => _leaving = null);
    });
    _keepDraft();
  }

  void _scrollTop() {
    if (_scroll.hasClients && _scroll.offset > 0) _scroll.jumpTo(0);
  }

  AboutStep? get _previous => switch (_step) {
    AboutStep.birth || AboutStep.age => AboutStep.name,
    AboutStep.gender => _ageOnly ? AboutStep.age : AboutStep.birth,
    _ => null,
  };

  void _back() {
    if (_saving || _checking) return;
    if (_sheetOpen) return _closeSheet();
    final p = _previous;
    if (p != null) _go(p, forward: false);
  }

  void _continue() {
    switch (_step) {
      case AboutStep.name:
        if (!_nameReady) return;
        _go(_ageOnly ? AboutStep.age : AboutStep.birth);
      case AboutStep.birth:
        if (_birthCheck != BirthCheck.ok) return;
        _openSheet();
      case AboutStep.age:
        _openSheet();
      case AboutStep.gender:
        _save();
      case AboutStep.done:
        final s = _saved;
        if (s != null) widget.onDone?.call(s);
      case AboutStep.tooYoung:
        break;
    }
  }

  void _useAgeOnly() {
    setState(() {
      _ageOnly = true;
      _belowMin = false;
      _birthNote = null;
    });
    _go(AboutStep.age);
  }

  void _useBirthMonth({String? note}) {
    setState(() {
      _ageOnly = false;
      _belowMin = false;
      _birthNote = note;
    });
    _go(AboutStep.birth, forward: false);
  }

  // ---- the confirm sheet -------------------------------------------------------------------------------

  void _openSheet() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _sheetOpen = true;
      _note = null;
    });
    _sheet.forward();
  }

  void _closeSheet() {
    if (_checking) return;
    _sheet.reverse().whenCompleteOrCancel(() {
      if (mounted && _sheet.isDismissed) setState(() => _sheetOpen = false);
    });
  }

  Future<void> _confirmed() async {
    if (_checking) return;
    final years = _years;
    if (years < AgeRules.minimum) {
      // GI-41: only the birth date goes to the server, which keeps nothing and makes the account wait
      setState(() => _checking = true);
      final r = await ref.read(basicsSaverProvider).save(Basics.birthOnly(_birth));
      if (!mounted) return;
      setState(() => _checking = false);
      if (r case SaveRefused(kind: Refusal.nameNeeded || Refusal.genderNeeded)) {
        // the server counts 13 or more (this phone's clock is off, GI-54): carry on
        _closeSheet();
        _go(AboutStep.gender);
        return;
      }
      // anything else, even no network: this phone stops here
      _sheet.value = 0;
      setState(() => _sheetOpen = false);
      await _tooYoung();
      return;
    }
    setState(() => _over100Confirmed = years > AgeRules.confirmAbove);
    _hop();
    _closeSheet();
    _go(AboutStep.gender);
  }

  Future<void> _tooYoung() async {
    final store = ref.read(launchStoreProvider);
    _draftTimer?.cancel();
    await store.setUnder13Until(clock.now().add(const Duration(days: 7)));
    await store.setBasicsDraft(null);
    unawaited(ref.read(basicsSaverProvider).signOut());
    if (!mounted) return;
    // nothing about the child stays on the screen either
    _first.clear();
    _last.clear();
    _gender = null;
    _go(AboutStep.tooYoung);
  }

  // ---- saving -------------------------------------------------------------------------------------

  Future<void> _save() async {
    final g = _gender;
    if (g == null || _saving) return;
    setState(() {
      _saving = true;
      _slow = false;
      _note = null;
    });
    _slowTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _saving) setState(() => _slow = true);
    });
    final r = await ref
        .read(basicsSaverProvider)
        .save(
          Basics(
            firstName: _first.text,
            lastName: _last.text,
            gender: g,
            birth: _birth,
            confirmOver100: _over100Confirmed,
          ),
        );
    _slowTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _saving = false;
      _slow = false;
    });
    switch (r) {
      case Saved():
        _draftTimer?.cancel();
        await ref.read(launchStoreProvider).setBasicsDraft(null);
        if (!mounted) return;
        setState(() {
          _saved = r;
          _petalsAt = _clock.value + .35;
        });
        HapticFeedback.mediumImpact();
        _go(AboutStep.done);
      case TooYoung():
        await _tooYoung();
      case SaveRefused(:final kind):
        switch (kind) {
          case Refusal.nameNeeded:
            _go(AboutStep.name, forward: false);
          case Refusal.genderNeeded:
            setState(() => _gender = null);
          case Refusal.birthInvalid:
            _useBirthMonth(note: AboutCopy.future);
          case Refusal.exactBirthNeeded:
            _useBirthMonth(note: AboutCopy.under18);
          case Refusal.birthLocked:
            if (_ageOnly) {
              _go(AboutStep.age, forward: false);
            } else {
              _go(AboutStep.birth, forward: false);
            }
            setState(() => _birthNote = AboutCopy.locked);
          case Refusal.confirmAge:
            _openSheet();
        }
      case SaveFailed(:final message):
        setState(() => _note = message);
    }
  }

  // ---- the a ------------------------------------------------------------------------------------------

  GsMood get _mood {
    if (_saving || _checking) return GsMood.thinking;
    return switch (_step) {
      AboutStep.done => GsMood.celebrating,
      AboutStep.tooYoung => GsMood.happy,
      AboutStep.name when NameRules.bad(_first.text) || NameRules.bad(_last.text) => GsMood.worried,
      AboutStep.age when _belowMin => GsMood.worried,
      _ when _cheer => GsMood.happy,
      _ => GsMood.listening,
    };
  }

  /// Where a listening a looks (0–10): along the name as it is typed, otherwise down at the answer.
  int get _gaze => _step == AboutStep.name && _firstFocus.hasFocus ? math.min(10, _first.text.length) : 0;

  // ---- after layout: the keyboard (GI-63) --------------------------------------------------------------

  void _afterLayout(double keyboard, bool compact) {
    final page = _pageKey.currentContext?.findRenderObject() as RenderBox?;
    final dock = _dockKey.currentContext?.findRenderObject() as RenderBox?;
    if (dock != null && dock.hasSize && (dock.size.height - _dockHeight).abs() > .5) {
      setState(() => _dockHeight = dock.size.height);
    }
    if (_step == AboutStep.name && _leaving == null && keyboard == 0 && !compact && page != null) {
      final last = _lastFieldKey.currentContext?.findRenderObject() as RenderBox?;
      if (last != null && last.attached && last.hasSize) {
        _regularBottom = last.localToGlobal(Offset(0, last.size.height), ancestor: page).dy;
      }
    }
    if (keyboard > 0 && keyboard != _lastKeyboard) {
      _visible?.cancel();
      _visible = Timer(const Duration(milliseconds: 360), _keepFieldVisible);
    }
    _lastKeyboard = keyboard;
  }

  /// The field being typed in stays above Continue and the keyboard.
  void _keepFieldVisible() {
    if (!mounted || !_scroll.hasClients) return;
    final page = _pageKey.currentContext?.findRenderObject() as RenderBox?;
    final key = _lastFocus.hasFocus ? _lastFieldKey : _firstFieldKey;
    final field = key.currentContext?.findRenderObject() as RenderBox?;
    if (page == null || field == null || !field.attached) return;
    final mq = MediaQuery.of(context);
    final room = mq.size.height - mq.viewInsets.bottom - _dockHeight;
    final bottom = field.localToGlobal(Offset(0, field.size.height), ancestor: page).dy;
    final want = bottom + 10 - room;
    if (want > _scroll.offset) _scroll.jumpTo(want.clamp(0.0, _scroll.position.maxScrollExtent));
  }

  void _focusChanged() {
    if (mounted) setState(() {});
    if (_firstFocus.hasFocus || _lastFocus.hasFocus) {
      _visible?.cancel();
      _visible = Timer(const Duration(milliseconds: 360), _keepFieldVisible);
    }
  }

  bool _focusListening = false;

  // ---- layout -------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (!_focusListening) {
      _focusListening = true;
      _firstFocus.addListener(_focusChanged);
      _lastFocus.addListener(_focusChanged);
    }
    final mq = MediaQuery.of(context);
    final reduced = mq.disableAnimations;
    final width = mq.size.width;
    final height = mq.size.height;
    final safeTop = mq.padding.top;
    final keyboard = mq.viewInsets.bottom;
    final viewport = height - keyboard;
    final regular = _regularBottom;
    final compact =
        _step == AboutStep.name && keyboard > 0 && (regular == null || regular + 8 > viewport - _dockHeight);
    // with large text the a moves up into the top bar, so the headline has the whole width (GI-60)
    final bigText = mq.textScaler.scale(10) / 10 > 1.3;
    final aInBar = compact || bigText;
    final short = height < 700;
    final route = ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation;
    final move = reduced ? const Duration(microseconds: 1) : const Duration(milliseconds: 320);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _afterLayout(keyboard, compact);
    });

    // one headline size for every step: as big as fits beside the a (the board's 42 px on a 390 px phone)
    final heroWidth = width - 2 * AdSpace.side - (aInBar ? 0 : 102);
    final h1 = HeadlineFit.fitted(KpType.h1(), 'old are you?', width - 2 * AdSpace.side - 102);
    final h1Compact = HeadlineFit.fitted(
      KpType.h1(compact: true),
      AboutCopy.nameHeadlineCompact,
      width - 2 * AdSpace.side,
    );

    Widget headline(String text, {double? room, bool oneLine = false}) {
      final style = oneLine ? h1Compact : h1;
      final grow = HeadlineFit.grow(style, HeadlineFit.longestWord(style, text), room ?? heroWidth);
      return Semantics(
        header: true,
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: grow,
          child: CssParagraph(text, style: style),
        ),
      );
    }

    // on a short phone the questions after your name sit a little higher (the a glides up with them)
    final heroTop = aInBar ? 16.0 : (short && _step != AboutStep.name ? 24.0 : 44.0);
    Widget heroRow(Widget child) => Padding(
      padding: EdgeInsets.only(top: heroTop),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: child),
          if (!aInBar) const SizedBox(width: 102, height: 92),
        ],
      ),
    );

    // ---- each step ----

    Widget body(AboutStep step) => switch (step) {
      AboutStep.name => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // the a and its bubble sit above the question; with the keyboard up they glide into the top bar and the
          // question folds to one line, all on the same curve (GI-63)
          AnimatedContainer(
            duration: move,
            curve: Curves.easeInOutCubic,
            height: !aInBar ? 44 + 92 + 14 : (compact ? 6 : 16),
          ),
          _Part(
            0,
            AnimatedSize(
              duration: move,
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topLeft,
              child: AnimatedSwitcher(
                duration: move,
                // the old size fades out in the first half, the new one in during the second: never both at once
                switchInCurve: const Interval(.5, 1),
                switchOutCurve: const Interval(.5, 1),
                layoutBuilder: (current, previous) =>
                    Stack(alignment: Alignment.topLeft, children: [...previous, ?current]),
                child: KeyedSubtree(
                  key: ValueKey(compact),
                  child: compact
                      ? headline(AboutCopy.nameHeadlineCompact, room: width - 2 * AdSpace.side, oneLine: true)
                      : headline(AboutCopy.nameHeadline, room: width - 2 * AdSpace.side),
                ),
              ),
            ),
          ),
          AnimatedContainer(duration: move, curve: Curves.easeInOutCubic, height: compact ? 14 : 24),
          _Part(
            1,
            KeyedSubtree(
              key: _firstFieldKey,
              child: NameField(
                controller: _first,
                focusNode: _firstFocus,
                label: AboutCopy.first,
                placeholder: AboutCopy.firstHint,
                autofill: AutofillHints.givenName,
                bad: NameRules.bad(_first.text),
                compact: compact,
                onSubmitted: (_) => _lastFocus.requestFocus(),
              ),
            ),
          ),
          _NoteLine(text: NameRules.bad(_first.text) ? AboutCopy.nameBad : null),
          SizedBox(height: compact ? 10 : 12),
          _Part(
            2,
            KeyedSubtree(
              key: _lastFieldKey,
              child: NameField(
                controller: _last,
                focusNode: _lastFocus,
                label: AboutCopy.last,
                aside: AboutCopy.optional,
                placeholder: AboutCopy.lastHint,
                autofill: AutofillHints.familyName,
                bad: NameRules.bad(_last.text),
                compact: compact,
                action: TextInputAction.done,
                onSubmitted: (_) => _continue(),
              ),
            ),
          ),
          _NoteLine(text: NameRules.bad(_last.text) && !NameRules.bad(_first.text) ? AboutCopy.nameBad : null),
        ],
      ),
      AboutStep.birth => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Part(0, heroRow(headline(AboutCopy.birthHeadline))),
          SizedBox(height: short ? 10 : 14),
          _Part(1, Text(AboutCopy.birthWhy, style: KpType.why)),
          SizedBox(height: short ? 16 : 22),
          _Part(
            2,
            BirthWheel(
              month: _month,
              year: _year,
              firstYear: _today.year - AgeRules.oldest,
              lastYear: _today.year,
              rows: short ? 3 : 5,
              onChanged: (m, y) {
                setState(() {
                  _month = m;
                  _year = y;
                  _birthNote = null;
                });
                _keepDraft();
              },
            ),
          ),
          const SizedBox(height: 14),
          _Part(3, _AgeLine(check: _birthCheck, years: _years, note: _birthNote)),
          _Part(4, TextLinkButton(label: AboutCopy.onlyAge, onTap: _useAgeOnly)),
        ],
      ),
      AboutStep.age => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Part(0, heroRow(headline(AboutCopy.ageHeadline))),
          SizedBox(height: short ? 10 : 14),
          _Part(1, Text(AboutCopy.ageWhy, style: KpType.why)),
          SizedBox(height: short ? 18 : 30),
          _Part(
            2,
            AgeDial(
              compact: short,
              value: _age,
              min: AgeRules.estimateFrom,
              max: AgeRules.oldest,
              onChanged: (v) {
                setState(() {
                  _age = v;
                  _belowMin = false;
                  _birthNote = null;
                });
                _keepDraft();
              },
              onBelowMin: () {
                HapticFeedback.lightImpact();
                setState(() => _belowMin = true);
              },
            ),
          ),
          SizedBox(height: short ? 18 : 26),
          _Part(3, _EstimateCard(age: _age, under18: _belowMin, note: _birthNote)),
          _Part(4, TextLinkButton(label: AboutCopy.exact, onTap: _useBirthMonth)),
        ],
      ),
      AboutStep.gender => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Part(0, heroRow(headline(AboutCopy.genderHeadline))),
          SizedBox(height: short ? 10 : 14),
          _Part(1, Text(AboutCopy.genderWhy, style: KpType.why)),
          SizedBox(height: short ? 16 : 22),
          _Part(
            2,
            ChoiceList<Gender>(
              label: 'Gender',
              choices: [for (final g in Gender.values) (g, g.label)],
              selected: _gender,
              compact: short,
              onSelect: (g) {
                if (_saving) return;
                if (g != _gender) _hop();
                setState(() {
                  _gender = g;
                  _note = null;
                });
                _keepDraft();
              },
            ),
          ),
        ],
      ),
      AboutStep.done => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // the a says it, in its bubble, above the card
          if (!aInBar) SizedBox(height: heroTop + 92) else const SizedBox(height: 16),
          if (aInBar) _Part(0, headline('${AboutCopy.nice}${NameRules.friendly(_first.text)}!')),
          SizedBox(height: aInBar ? 18 : 22),
          _Part(1, _YouCard(first: _first.text, last: _last.text, birth: _birth, years: _years, gender: _gender)),
          const SizedBox(height: 16),
          _Part(2, Text(_saved?.teen == true ? AboutCopy.nextTeen(_years) : AboutCopy.nextAdult, style: KpType.why)),
        ],
      ),
      AboutStep.tooYoung => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Part(0, heroRow(headline(AboutCopy.seeYouHeadline))),
          const SizedBox(height: 16),
          _Part(1, Text(AboutCopy.seeYouBody, style: KpType.why)),
          const SizedBox(height: 26),
          const _Part(2, ChildlineCard()),
        ],
      ),
    };

    // ---- the top bar: back, and where you are ----

    final dots = switch (_step) {
      AboutStep.name => 0,
      AboutStep.birth || AboutStep.age => 1,
      AboutStep.gender => 2,
      _ => 3,
    };
    final bubbleShown = _step == AboutStep.name || (_step == AboutStep.done && !aInBar);
    final bubbleInBar = aInBar && _step == AboutStep.name;
    final back = _previous != null && !_saving;
    final barH = aInBar ? 56.0 : 48.0;
    final topBar = AnimatedContainer(
      duration: move,
      curve: Curves.easeInOutCubic,
      height: 40 + barH,
      alignment: Alignment.bottomLeft,
      child: SizedBox(
        height: barH,
        child: Row(
          children: [
            AnimatedSize(
              duration: move,
              curve: Curves.easeInOutCubic,
              child: back
                  ? Transform.translate(
                      offset: const Offset(-12, 0),
                      child: KpBackButton(onTap: _back, label: _backLabel),
                    )
                  : const SizedBox(height: 48),
            ),
            if (_step != AboutStep.tooYoung)
              SlideIn(
                route: route,
                start: .24,
                child: AnimatedOpacity(
                  opacity: bubbleInBar ? 0 : 1,
                  duration: move,
                  child: StepDots(at: dots, allDone: _step == AboutStep.done),
                ),
              ),
          ],
        ),
      ),
    );

    // ---- the steps, sliding past each other ----

    final leaving = _leaving;
    final steps = Stack(
      children: [
        if (leaving != null)
          KeyedSubtree(
            key: ValueKey('out-${leaving.name}'),
            child: _StepScope(
              animation: _stepAnim,
              incoming: false,
              forward: _forward,
              reduced: reduced,
              child: IgnorePointer(child: ExcludeSemantics(child: body(leaving))),
            ),
          ),
        KeyedSubtree(
          key: ValueKey(_step.name),
          child: _StepScope(
            animation: leaving != null ? _stepAnim : route,
            incoming: true,
            forward: _forward,
            reduced: reduced,
            fromCode: leaving == null,
            child: body(_step),
          ),
        ),
      ],
    );

    // ---- the a's seat (it is painted on top, so it can hop onto the sheet) and its bubble ----

    final aScale = aInBar ? .56 : 1.0;
    final aLeft = aInBar ? width - AdSpace.side - 100 * aScale + 4 : width - AdSpace.side - 100 + 6;
    final aTop = aInBar ? safeTop + 40 + 3 : safeTop + 88 + heroTop;
    final seat = AnimatedPositioned(
      duration: move,
      curve: Curves.easeInOutCubic,
      left: aLeft,
      top: aTop,
      child: AnimatedScale(
        duration: move,
        curve: Curves.easeInOutCubic,
        alignment: Alignment.topLeft,
        scale: aScale,
        child: KeyedSubtree(
          key: _seatKey,
          child: SizedBox.fromSize(size: GetStartedA.size),
        ),
      ),
    );
    final friendly = NameRules.friendly(_first.text);
    final named = NameRules.ok(_first.text);
    final saying = _step == AboutStep.done || _leaving == AboutStep.done;
    final bubble = AnimatedPositioned(
      duration: move,
      curve: Curves.easeInOutCubic,
      left: AdSpace.side,
      right: width - aLeft - (aInBar ? 0 : 4),
      top: aTop,
      height: GetStartedA.size.height * aScale,
      child: Align(
        alignment: Alignment.centerRight,
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          // arriving from the code screen, it pops out once the page has turned
          child: AnimatedBuilder(
            animation: route,
            builder: (context, _) => SpeechBubble(
              prefix: saying ? AboutCopy.nice : (named ? 'namaste, ' : AboutCopy.hello),
              highlight: saying || named ? friendly : '',
              suffix: saying || named ? '!' : '',
              shown: bubbleShown && route.value >= .55,
              compact: aInBar,
              maxLines: aInBar ? 1 : 2,
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
          child: Toran(time: _clock, reduced: reduced),
        ),
        FillColumn(
          key: _pageKey,
          minHeight: viewport,
          top: Padding(
            padding: EdgeInsets.fromLTRB(AdSpace.side, safeTop, AdSpace.side, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [topBar, steps]),
          ),
          bottom: SizedBox(height: _step == AboutStep.tooYoung ? math.max(24, mq.padding.bottom) : _dockHeight + 8),
        ),
        seat,
        bubble,
      ],
    );

    // ---- Continue, always in the same place ----

    final busy = _saving || _checking;
    final ready = switch (_step) {
      AboutStep.name => _nameReady,
      AboutStep.birth => _birthCheck == BirthCheck.ok,
      AboutStep.age => true,
      AboutStep.gender => _gender != null,
      AboutStep.done => true,
      AboutStep.tooYoung => false,
    };
    final dock = Positioned(
      left: 0,
      right: 0,
      bottom: keyboard,
      child: _Dock(
        key: _dockKey,
        excluded: _sheetOpen,
        route: route,
        reduced: reduced,
        hidden: _step == AboutStep.tooYoung,
        bottomPad: keyboard > 0 ? 12 : math.max(20, mq.padding.bottom),
        note: _slow ? AboutCopy.slow : _note,
        child: PrimaryButton(
          label: AboutCopy.next,
          busyLabel: AboutCopy.saving,
          loading: _saving,
          onPressed: ready && !busy ? _continue : null,
          shine: ready && !busy && !reduced && _step == AboutStep.done
              ? ShineTiming(time: _clock, delay: _clock.value + .8)
              : null,
        ),
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Stack(
        children: [
          // the code screen's paper shows through while the page changes; this one takes over at the end
          Positioned.fill(
            child: FadeTransition(
              opacity: CurvedAnimation(parent: route, curve: const Interval(.9, 1)),
              child: const ColoredBox(color: AdColors.paper),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: keyboard),
            child: ExcludeSemantics(
              excluding: _sheetOpen,
              child: SingleChildScrollView(controller: _scroll, child: page),
            ),
          ),
          dock,
          if (_sheetOpen) ...[
            Positioned.fill(
              child: FadeTransition(
                opacity: _sheet,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _closeSheet,
                  child: const ColoredBox(color: AdColors.scrim),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
                  CurvedAnimation(parent: _sheet, curve: const Cubic(.2, 1, .3, 1), reverseCurve: Curves.easeInCubic),
                ),
                child: _ConfirmSheet(
                  title: _ageOnly ? AboutCopy.confirmAge(_age) : AboutCopy.confirmBirth(_month, _year),
                  why: (_years > AgeRules.confirmAbove ? AboutCopy.over100(_years) : '') + AboutCopy.confirmWhy,
                  slotKey: _slotKey,
                  checking: _checking,
                  bottomPad: math.max(20, mq.padding.bottom),
                  onYes: _confirmed,
                  onChange: _closeSheet,
                ),
              ),
            ),
          ],
          // the a: in its seat, or hopping down onto the sheet
          Positioned.fill(
            child: IgnorePointer(
              child: _SeatFlight(
                seatKey: _seatKey,
                slotKey: _slotKey,
                sheet: _sheet,
                repaint: _flightRepaint,
                child: GetStartedA(time: _clock, mood: _mood, digits: _gaze, reduced: reduced),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: _Petals(time: _clock, firedAt: _petalsAt, seatKey: _seatKey, reduced: reduced),
            ),
          ),
        ],
      ),
    );
  }

  String get _backLabel => switch (_previous) {
    AboutStep.name => 'Back to your name',
    AboutStep.birth => 'Back to when you were born',
    AboutStep.age => 'Back to your age',
    _ => 'Back',
  };
}

// ---- moving between steps ---------------------------------------------------------------------------------

/// How the parts of a step move: in from one side, staggered, or out to the other.
class _StepScope extends InheritedWidget {
  const _StepScope({
    required this.animation,
    required this.incoming,
    required this.forward,
    required this.reduced,
    this.fromCode = false,
    required super.child,
  });

  final Animation<double> animation;
  final bool incoming;
  final bool forward;
  final bool reduced;

  /// Arriving from the code screen (the route's own animation): a little later, after the code page has stepped aside.
  final bool fromCode;

  static _StepScope? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_StepScope>();

  @override
  bool updateShouldNotify(_StepScope old) =>
      old.animation != animation || old.incoming != incoming || old.forward != forward || old.reduced != reduced;
}

/// One part of a step ([order] 0, 1, 2…): parts come in one after another, 80 ms apart.
class _Part extends StatelessWidget {
  const _Part(this.order, this.child);
  final int order;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = _StepScope.of(context);
    if (s == null) return child;
    return AnimatedBuilder(
      animation: s.animation,
      child: child,
      builder: (context, child) {
        final v = s.animation.value;
        if (s.incoming) {
          if (v >= 1) return child!;
          // the old step has mostly gone before the new one shows, so the two never read on top of each other
          final start = math.min(.5, (s.fromCode ? .26 : .24) + order * .07);
          final e = Interval(start, math.min(1, start + .5), curve: Curves.easeOutCubic).transform(v);
          if (s.reduced) return Opacity(opacity: e, child: child);
          return Opacity(
            opacity: e,
            child: Transform.translate(offset: Offset((s.forward ? 44 : -44) * (1 - e), 0), child: child),
          );
        }
        final e = const Interval(0, .3, curve: Curves.easeInCubic).transform(v);
        if (e >= 1) return const SizedBox.shrink();
        if (s.reduced) return Opacity(opacity: 1 - e, child: child);
        return Opacity(
          opacity: 1 - e,
          child: Transform.translate(offset: Offset((s.forward ? -44 : 44) * e, 0), child: child),
        );
      },
    );
  }
}

// ---- pieces of the steps -------------------------------------------------------------------------------------

/// A problem under a field, in body size with the alert mark; nothing when [text] is null.
class _NoteLine extends StatelessWidget {
  const _NoteLine({required this.text});
  final String? text;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final t = text;
    return AnimatedSize(
      duration: reduced ? const Duration(microseconds: 1) : const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topLeft,
      child: t == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Semantics(
                liveRegion: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(padding: EdgeInsets.only(top: 2, right: 8), child: AlertMark(size: 18)),
                    Expanded(child: Text(t, style: KpType.helpBad)),
                  ],
                ),
              ),
            ),
    );
  }
}

/// "That makes you 22." under the wheel, the number rolling as the wheel turns; or why the date can't be right.
class _AgeLine extends StatelessWidget {
  const _AgeLine({required this.check, required this.years, required this.note});
  final BirthCheck check;
  final int years;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final bad = switch (check) {
      BirthCheck.future => AboutCopy.future,
      BirthCheck.thisYear => AboutCopy.thisYear,
      BirthCheck.ok => note,
    };
    if (bad != null) {
      return Semantics(
        liveRegion: true,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(color: AdColors.white, borderRadius: BorderRadius.all(Radius.circular(18))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(padding: EdgeInsets.only(top: 2, right: 10), child: AlertMark(size: 18)),
              Expanded(child: Text(bad, style: KpType.helpBad)),
            ],
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        liveRegion: true,
        label: AboutCopy.makesYou(years),
        excludeSemantics: true,
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: const BoxDecoration(color: AdColors.white, borderRadius: BorderRadius.all(Radius.circular(999))),
          // wraps at large text (GI-60); the number rolls as the wheel turns
          child: Text.rich(
            TextSpan(
              style: KpType.ageLine,
              children: [
                const TextSpan(text: 'That makes you '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: RollingNumber(value: years, style: KpType.ageLineNumber),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Doctors will see “about 52”": an age on its own is an estimate, for adults. Below 18 it turns into the reason we
/// need the month and year (GI-46).
class _EstimateCard extends StatelessWidget {
  const _EstimateCard({required this.age, required this.under18, required this.note});
  final int age;
  final bool under18;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final warn = under18 || note != null;
    final text = note ?? (under18 ? AboutCopy.under18 : '${AboutCopy.estimate(age)} ${AboutCopy.adultsOnly}');
    return Semantics(
      liveRegion: warn,
      child: AnimatedContainer(
        duration: reduced ? const Duration(microseconds: 1) : const Duration(milliseconds: 220),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: warn ? AdColors.noteFill : AdColors.white,
          borderRadius: const BorderRadius.all(Radius.circular(20)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(padding: EdgeInsets.only(top: 1, right: 12), child: InfoMark()),
            Expanded(
              child: AnimatedSize(
                duration: reduced ? const Duration(microseconds: 1) : const Duration(milliseconds: 220),
                alignment: Alignment.topLeft,
                child: Text(text, style: KpType.why.copyWith(color: warn ? AdColors.ink : AdColors.body)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What you told us, on a white card with a painted vermilion dot border; the birth date carries a small lock (GI-42).
class _YouCard extends StatelessWidget {
  const _YouCard({
    required this.first,
    required this.last,
    required this.birth,
    required this.years,
    required this.gender,
  });
  final String first;
  final String last;
  final Birth birth;
  final int years;
  final Gender? gender;

  @override
  Widget build(BuildContext context) {
    final name = [NameRules.tidy(first), NameRules.tidy(last)].where((s) => s.isNotEmpty).join(' ');
    Widget row(String key, String value, {bool lock = false}) => Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AdColors.softLine, width: 1.5)),
      ),
      child: Row(
        children: [
          Text(key, style: KpType.cardKey),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (lock) const Padding(padding: EdgeInsets.only(right: 6), child: LockMark()),
                Flexible(
                  child: Text(value, style: KpType.cardValue, textAlign: TextAlign.right),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return CustomPaint(
      foregroundPainter: const _CardDots(),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
        decoration: const BoxDecoration(
          color: AdColors.white,
          borderRadius: BorderRadius.all(Radius.circular(24)),
          boxShadow: [BoxShadow(color: Color(0x0F1A1410), blurRadius: 24, offset: Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(name, style: KpType.cardName),
            const SizedBox(height: 12),
            switch (birth) {
              BirthMonth(:final year, :final month) => row(
                AboutCopy.born,
                '${monthNames[month - 1]} $year',
                lock: true,
              ),
              AgeOnly() => row(AboutCopy.age, 'about $years', lock: true),
            },
            if (birth is BirthMonth) row(AboutCopy.age, '$years'),
            if (gender != null) row(AboutCopy.gender, gender!.label),
          ],
        ),
      ),
    );
  }
}

class _CardDots extends CustomPainter {
  const _CardDots();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(7);
    final metric = (Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(17)))).computeMetrics().first;
    final n = (metric.length / 10).floor();
    final step = metric.length / n;
    final p = Paint()..color = AdColors.vermilion.withValues(alpha: .55);
    for (var i = 0; i < n; i++) {
      canvas.drawCircle(metric.getTangentForOffset(i * step)!.position, 1.4, p);
    }
  }

  @override
  bool shouldRepaint(_CardDots old) => false;
}

/// Continue, docked at the bottom above a soft fade (and above the keyboard when it is open). Arriving from the code
/// screen it rises in.
class _Dock extends StatelessWidget {
  const _Dock({
    super.key,
    required this.route,
    required this.reduced,
    required this.hidden,
    required this.bottomPad,
    required this.note,
    required this.child,
    this.excluded = false,
  });

  /// Under the confirm sheet: screen readers skip it.
  final bool excluded;
  final Animation<double> route;
  final bool reduced;
  final bool hidden;
  final double bottomPad;
  final String? note;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final rise = CurvedAnimation(
      parent: route,
      curve: const Interval(.4, .95, curve: Curves.easeOutCubic),
    );
    final n = note;
    final dock = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const IgnorePointer(
          child: SizedBox(
            height: 20,
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
        ColoredBox(
          color: AdColors.paper,
          child: Padding(
            padding: EdgeInsets.fromLTRB(AdSpace.side, 2, AdSpace.side, bottomPad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedSize(
                  duration: reduced ? const Duration(microseconds: 1) : const Duration(milliseconds: 180),
                  alignment: Alignment.bottomLeft,
                  child: n == null
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Semantics(
                            liveRegion: true,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(padding: EdgeInsets.only(top: 2, right: 8), child: AlertMark(size: 18)),
                                Expanded(child: Text(n, style: KpType.helpBad)),
                              ],
                            ),
                          ),
                        ),
                ),
                child,
              ],
            ),
          ),
        ),
      ],
    );
    return ExcludeSemantics(
      excluding: excluded || hidden,
      child: AnimatedSlide(
        offset: hidden ? const Offset(0, 1.2) : Offset.zero,
        duration: reduced ? const Duration(microseconds: 1) : const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
        child: IgnorePointer(
          ignoring: hidden,
          child: reduced
              ? FadeTransition(opacity: rise, child: dock)
              : SlideTransition(
                  position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(rise),
                  child: dock,
                ),
        ),
      ),
    );
  }
}

/// "born in March 2004?": a sheet that rises from the bottom; the a hops down onto its top right corner (the slot)
/// and looks at the question.
class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.title,
    required this.why,
    required this.slotKey,
    required this.checking,
    required this.bottomPad,
    required this.onYes,
    required this.onChange,
  });

  final String title;
  final String why;
  final GlobalKey slotKey;
  final bool checking;
  final double bottomPad;
  final VoidCallback onYes;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return BlockSemantics(
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: title.replaceAll('\n', ' '),
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .9),
          decoration: const BoxDecoration(
            color: AdColors.paper,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [BoxShadow(color: Color(0x261A1410), blurRadius: 30, offset: Offset(0, -6))],
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(AdSpace.side, 12, AdSpace.side, bottomPad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: AdColors.line,
                      borderRadius: BorderRadius.all(Radius.circular(3)),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: MediaQuery.withClampedTextScaling(
                          maxScaleFactor: HeadlineFit.grow(
                            KpType.sheetTitle,
                            HeadlineFit.longestWord(KpType.sheetTitle, title),
                            width - 2 * AdSpace.side - 74,
                          ),
                          child: CssParagraph(title, style: KpType.sheetTitle),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    KeyedSubtree(key: slotKey, child: const SizedBox(width: 62, height: 54.56)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(why, style: KpType.why),
                const SizedBox(height: 22),
                PrimaryButton(label: AboutCopy.yes, busyLabel: AboutCopy.checking, loading: checking, onPressed: onYes),
                const SizedBox(height: 10),
                PrimaryButton(label: AboutCopy.change, tone: ButtonTone.outline, onPressed: checking ? null : onChange),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---- the a, painted on top ---------------------------------------------------------------------------------

/// Paints the a in its seat (wherever the page has put it: beside the headline, in the top bar, scrolled), and, as
/// [sheet] opens, carries it on a little hop down onto the sheet's slot. Decorative (GI-61).
class _SeatFlight extends SingleChildRenderObjectWidget {
  const _SeatFlight({
    required this.seatKey,
    required this.slotKey,
    required this.sheet,
    required this.repaint,
    required super.child,
  });

  final GlobalKey seatKey;
  final GlobalKey slotKey;
  final Animation<double> sheet;
  final Listenable repaint;

  @override
  _RenderSeatFlight createRenderObject(BuildContext context) => _RenderSeatFlight(seatKey, slotKey, sheet, repaint);

  @override
  void updateRenderObject(BuildContext context, _RenderSeatFlight renderObject) {
    renderObject
      ..seatKey = seatKey
      ..slotKey = slotKey
      ..sheet = sheet
      ..repaint = repaint
      ..markNeedsPaint(); // the page may have moved the seat
  }
}

class _RenderSeatFlight extends RenderProxyBox {
  _RenderSeatFlight(this.seatKey, this.slotKey, this.sheet, this._repaint);

  GlobalKey seatKey;
  GlobalKey slotKey;
  Animation<double> sheet;
  Listenable _repaint;
  set repaint(Listenable v) {
    if (v == _repaint) return;
    if (attached) {
      _repaint.removeListener(markNeedsPaint);
      v.addListener(markNeedsPaint);
    }
    _repaint = v;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _repaint.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _repaint.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void performLayout() {
    child!.layout(BoxConstraints.tight(GetStartedA.size));
    size = constraints.biggest;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => false;

  Rect? _rect(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return null;
    final global = MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);
    final topLeft = globalToLocal(global.topLeft);
    return topLeft & global.size;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final seat = _rect(seatKey);
    if (seat == null || child == null) return;
    var at = seat.topLeft;
    var scale = seat.width / GetStartedA.size.width;
    final v = sheet.value;
    final slot = v > 0 ? _rect(slotKey) : null;
    if (slot != null) {
      // a hop: up a little, then down onto the sheet
      final e = Curves.easeInOutCubic.transform(v);
      final p0 = seat.topLeft, p2 = slot.topLeft;
      final p1 = Offset((p0.dx + p2.dx) / 2, math.min(p0.dy, p2.dy) - 48);
      final u = 1 - e;
      at = p0 * (u * u) + p1 * (2 * u * e) + p2 * (e * e);
      final s1 = slot.width / GetStartedA.size.width;
      scale = scale + (s1 - scale) * e;
    }
    context.pushTransform(
      needsCompositing,
      offset,
      Matrix4.identity()
        ..translateByDouble(at.dx, at.dy, 0, 1)
        ..scaleByDouble(scale, scale, 1, 1),
      (c, o) => c.paintChild(child!, o),
    );
  }
}

/// Marigold petals from the a when About you is saved.
class _Petals extends StatelessWidget {
  const _Petals({required this.time, required this.firedAt, required this.seatKey, required this.reduced});
  final ValueListenable<double> time;
  final double? firedAt;
  final GlobalKey seatKey;
  final bool reduced;

  @override
  Widget build(BuildContext context) {
    if (firedAt == null || reduced) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, box) {
        final seat = seatKey.currentContext?.findRenderObject() as RenderBox?;
        final me = context.findRenderObject() as RenderBox?;
        var origin = Offset(box.maxWidth - 70, 180);
        if (seat != null && me != null && seat.attached && me.attached && seat.hasSize) {
          origin = me.globalToLocal(seat.localToGlobal(Offset(seat.size.width / 2, 20)));
        }
        return PetalBurst(time: time, firedAt: firedAt, origin: origin);
      },
    );
  }
}
