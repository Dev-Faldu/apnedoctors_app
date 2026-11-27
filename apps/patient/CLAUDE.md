# ApneDoctors patient app (Flutter)

Flutter 3.50 stable, Dart 3.14. iOS and Android from one codebase, identical design on both.

## Run

```bash
flutter pub get
flutter run                 # a connected phone, simulator or emulator
```

Supabase config is public and has defaults in `lib/core/config/env.dart`; override with
`--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...`. Never put a secret in the app.

## Check before every commit

```bash
flutter analyze             # must be clean
flutter test                # logic, layout and golden tests
```

Goldens are rendered on Linux (the CI platform). After an approved design change:
`flutter test --update-goldens test/goldens`, then look at every changed image before committing.

## Backend

`lib/core/backend/backend.dart` starts Supabase at launch (local only, never waits on the network) and exposes
`supabaseProvider`. Features read live data through small sources (e.g. `DoctorsOnlineSource` calls
`public.doctors_online()`). Live tests run the app's own code against the real project:

```bash
flutter test --dart-define=LIVE=true test/live
```

## Layout

```
lib/
  app/                 app shell and routes
  core/
    theme/             tokens.dart (every colour, type style, size); css_paragraph.dart (CSS line boxes)
    motion/            keyframes.dart: CSS keyframes and animations, evaluated from one clock
    brand/             the living "a" painter, the lockup, path helpers, generated lockup glyphs
    config/            public env
  features/
    launch/            decide_launch.dart: the pure launch router (GI-01..19, G17), launch_state.dart: its inputs;
                       launch_gate.dart: which opening plays (first open, returning, reduced motion)
    opening/           native splash → splash → hand-off (N00Splash); opening_spec.g.dart is generated
    welcome/           Welcome (N01Welcome): doorway painter, timings, doctors-online chip; doorway_hand_off.dart:
                       where the a stood when a door was tapped (the next screen carries it on)
    get_started/       GS1 (phone) and GS2 (code): the screens, their a (moods), the toran, marigold petals, the real
                       code sender and checker (Supabase phone OTP), CodeArrival (what moves between them)
  shared/
    indian_phone.dart  parses Indian mobile numbers as people type and paste them (GI-20..23)
    widgets/           the Getting-in kit: PhoneField (painted dot slots), CodeTiles (six painted tiles), PrimaryButton,
                       GoogleButton, LivingA (moods), KpScaffold, FillColumn, HoldScroll, kp_icons
test/                  unit, widget and golden tests (edge-case IDs in names)
tool/
  gen_opening_spec.py  writes opening_spec.g.dart and lockup_glyphs.g.dart from the board's own maths
  frames/              renders the app frame by frame (capture_test: the opening; walk_through_test: Welcome →
                       Get started and back; code_flow_test: phone → code → verified; for videos)
  design_compare/      renders the board frame by frame and diffs the two
```

## Moving between screens

Each door on Welcome opens its own path, and the move is part of the design. Welcome → Get started is the walk
through the doorway: Get started's route animation brings its paper, toran and page in and flies the a from where
Welcome left it (`DoorwayHandOff`); Welcome reads its own route's secondary animation to grow the doorway past you
and step everything else aside. Back reverses both. With reduced motion it is a cross-fade.

Get started → Code keeps the toran, the back button and the a perfectly still (the code screen draws them in the same
places, on the same clock via `CodeArrival.clockFrom`, while the phone screen hides its own); the phone page steps
aside to the left, the code page slides in from the right, and the number flies from its field into the pill.

## Large text (GI-60)

Every screen is checked at 200% text. The body scrolls; buttons grow taller. Fields whose content must stay on
one line (the phone number, the code digits) grow as far as their width allows and no further
(`fitScaler`, `digitScaler`). Labels and messages around them keep the person's full size.

## How the opening matches the board

- `tool/gen_opening_spec.py` repeats `docs/design/kalighat-pop/gen/splash.py` (same constants, same
  rounding, same Kaushan Script outlines) and writes Dart. Never hand-edit `*.g.dart`; change the generator.
- One clock (seconds) drives the splash and Welcome. Each moving part is a `CssAnim` + `Keyframes`
  with the board's exact delays, durations and cubic-béziers, including per-keyframe easing and fill modes.
- The opening is laid out in the board's 390×844 space centred on the screen; the hand-off target is
  measured from Welcome's real layout, so other screen sizes land exactly too.
- Things the browser does differently, handled on purpose: Skia dashing restarts per contour
  (`MeasuredPath.head`); CSS keeps 1/64 px line heights where Flutter rounds (`CssParagraph`);
  `box-shadow` blur is a Gaussian with sigma = blur / 2 (painted directly).
- Verify after any motion change: see `tool/design_compare/README.md`.

## Native splash and icon

Generated by `dart run flutter_native_splash:create` and `dart run flutter_launcher_icons` from the
config at the end of `pubspec.yaml`. The splash "a" (`assets/brand/splash_a*.png`, from
`tool/design_compare/splash_png.js`) is at scale 1 with its bounds centred: the app's first frame
starts from exactly that pose.
