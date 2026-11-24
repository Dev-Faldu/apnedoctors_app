# ApneDoctors: project memory

Read this at the start of every session. Newest sections first; they win over anything below them.
Keep it current: when a decision changes, change it here in the same commit.

Last updated: 2026-11-24.

## Milestone 1 built: first tap → native splash → opening → Welcome (2026-11-24, awaiting the founder's review)
- Fresh start (founder: "start fresh, from when someone first downloads the app and clicks the icon").
  New repo `Dev-Faldu/apnedoctors_app`, Flutter app at `apps/patient`, branch `flutter-v1`.
- Matched to `N00Splash` frame by frame at 60 fps, verified by rendering both and diffing every frame
  (`apps/patient/tool/design_compare`): during the splash, 0.02–0.17% of pixels differ by more than 40
  levels (anti-aliasing); Welcome text lands on Chrome's exact boxes (headline y 438.72, body 591.72, h 49.28).
  What remains is text rasterization (Chrome draws text slightly darker).
- Deliberate differences from the board, all small:
  1. The board starts from a home-screen icon. On a phone the OS animates the icon, then the native splash
     shows the "a" at scale 1 centred; the app's first frame starts there and grows into the hero pose on
     the board's own curve by 0.55 s. From 0.55 s on, the board's tracks are followed exactly.
  2. "Get started" shine: on the board a pale band rests on the button's left edge until its first sweep
     (a CSS fill-mode slip). The app keeps it off-button until it sweeps.
  3. "14 doctors online now" chip: hidden until a real count exists (no doctor directory yet). Never a
     made-up number. With data it renders exactly like the board.
  4. Touch targets are 48 px tall (board: 44 and 41) without moving anything visible.
  5. At large text sizes the top bar and chip reflow and the page scrolls (EC-A11Y-01).
  6. Reduced motion: Welcome's settled frame without the shine band.
- Opened before (no sign-in yet): Welcome's own entrance (`N01Welcome`). Reduced motion: Welcome settled.
  "Get started", "I already have an account" and "For doctors" don't lead anywhere yet: the next screens
  come after the founder approves this one.
- Not possible from the cloud container: iOS simulator (needs a Mac) and Android emulator (no
  virtualisation; Android SDK downloads blocked). Videos come from Flutter's renderer frame by frame.
  To record real simulators, the founder can connect their Mac (Remote Control).

## Fresh start and setup (founder, 2026-11-24)
- Rebuild from scratch in Flutter (iOS + Android, identical design). Patient app first; later a pro app for
  doctors, a hospital system and admin.
- Repo: `Dev-Faldu/apnedoctors_app` (public). The old Expo app, old Supabase and old design history stay in
  `Dev-Faldu/apnedoctors-app`, untouched.
- Supabase: new project `yljfnbudjdijwjshqaba` (URL and publishable key in `apps/patient/lib/core/config/env.dart`,
  public by design). Old project `litnckjlxkjxsnmmvbzp` is legacy. Access tokens are never committed or
  stored; the founder shared one on 2026-11-24 and should revoke it.
- Toolchain: Flutter 3.50.1, Dart 3.14, flutter_riverpod, go_router, shared_preferences,
  flutter_native_splash, flutter_launcher_icons. Bundle ID `app.apnedoctors` (same as the legacy app).

## Design: "Kalighat pop" (approved, do not change)
- Modern layouts with Indian heritage, in the style of 19th-century Bengali Kalighat painting: bold brushed
  outlines heavier on one side, painted white dot borders, one bold folk colour per screen, warm paper.
- Colours: paper #FBF7EF, vermilion (brand) #C8302B, ink #1A1410, haldi #EFB12A, green #62A65A,
  indigo #5674C4, heart red #E0484E. All in `tokens.dart`.
- Fonts (OFL, bundled): Anek Latin (variable; headlines wide and heavy) for all UI; Kaushan Script for the
  wordmark only, drawn from outlines. Never a Kaushan "A": the logo "a" stands in for it.
- Logo: the living "a" (bowl circle r 45, stroke 16; stem `M275 86 V156 Q275 176 294 176`; ink eyes r 8),
  drawn in code. It breathes, blinks, looks around and reacts to real moments. Moods: breathing, listening,
  waking, asleep, happy, worried, sorry, celebrating (each designed with the screen that uses it).
- Boards: `docs/design/kalighat-pop/N00Splash.dc.html` (opening into Welcome, timings in `gen/splash.py`),
  `N01Welcome.dc.html`, `kp.css`. The Liquid Glass direction (G01) was rejected.
- Founder's rules: no plain emoji; no static screens (respect reduced motion); don't copy Instagram or
  Snapchat; one idea per screen; 24 px margins; body 16 px+; WCAG AA; check 360×640 and 390×844;
  motion silky, one curve, no zigzag, no jumps.

## Product decisions
- Sign-in: phone number (OTP) and Google. Phone OTP needs a paid SMS provider: decide before building it
  (zero budget today).
- Navigation: Today, Discover, the living "a" in the centre (all care actions + SOS), Ghar (family), Care.
  Account from your photo on Today.
- Alive like a person: the app has a day (dawn, noon, dusk, night; night dims) and lives India's year
  (monsoon, Diwali, summer); it remembers you and checks on you after a consult; it shows real people present.
- Daily pull from real value only: verified doctors' shorts, live sessions and free Q&A; the family health
  feed; live lock-screen activities. No endless feed, fake urgency, streak guilt, games or XP.
- The old "organs gang chat" survives only as one small optional companion: off by default, crisis screen
  first, hands off to a real doctor.
- English only for now. Ages 13+; 13–17 need verified parental consent before chat, public posts or medicines.

## The founder and how they work
- Dev Faldu, solo founder, zero budget (free tiers only until told otherwise). Writes informally: read the
  intent. Wants short, direct replies, company-grade work, nothing fake.
- One screen at a time: plan → build → run → compare with the board → refine → show. Don't build ahead of
  what's approved. Ask before anything destructive, costly or hard to undo.

## Open questions for the founder
- Approve milestone 1 (videos in the session) and the six deliberate differences above.
- Where "Get started" goes next: sign-in design (phone OTP needs an SMS budget).
- Source of the live "doctors online" count (needs the doctor directory in Supabase).
- Connect a Mac to record iOS simulator videos?
