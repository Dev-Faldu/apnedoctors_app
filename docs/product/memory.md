# ApneDoctors: project memory

Read this at the start of every session. Newest sections first; they win over anything below them.
Keep it current: when a decision changes, change it here in the same commit.

Last updated: 2026-11-24 (backend connected).

## Backend connected for real (founder: "connect it, no fake, no mock, no dummy", 2026-11-24)
- The app talks to the live Supabase project `yljfnbudjdijwjshqaba` (ap-south-1, Mumbai; Postgres 17):
  `supabase_flutter` starts at launch without waiting for the network.
- Database, in `supabase/migrations/` (append-only), applied with `supabase/deploy.py` through the Management API
  (tracked in `supabase_migrations.schema_migrations`, the Supabase CLI's table):
  - `doctors`: the verified directory (name, 14-digit ABDM HPR ID, `verified_at`; rows added and verified by the
    verification process only, never by the app);
  - `doctor_presence`: a verified doctor's last "I'm here"; online = seen in the last 2 minutes;
  - `doctors_online()`: public, returns `{count, faces[≤3 initials]}` of verified doctors online now;
  - `set_doctor_presence(online)`: signed-in verified doctors only.
  RLS on every table; the public can run only `doctors_online`; the `private` schema is closed; Supabase's own
  `rls_auto_enable()` helper is closed to the public (its trigger still enables RLS on new tables).
- Welcome's "doctors online" chip now reads the real count every 30 s. Today the answer is
  `{"count": 0, "faces": []}` (no verified doctors yet), so the chip is hidden. It appears by itself when real
  verified doctors go online. A count is trusted for 2 minutes; if the backend can't be reached for longer, the
  chip goes away. During the hand-off the chip can't appear or vanish (the doorway would move); afterwards it slides.
- Auth: email sign-up turned off (decided methods are phone and Google; an open email sign-up let anyone make
  accounts with the public key). Anonymous accounts off. Google and phone sign-in are not set up yet.
- Verified three ways: 15 database tests on Supabase's own Postgres 17 image (`supabase/tests/test_database.py`),
  live checks against the real project (`supabase/tests/live_check.py`: public can count, can't read or write the
  directory, RLS everywhere, migrations applied, security advisor clean of errors, auth methods), and the app's own
  Dart code against the real project (`apps/patient/test/live`).
- Cloud environment "ApneDoctors" (personal) allows `yljfnbudjdijwjshqaba.supabase.co` and `api.supabase.com`; the
  Supabase access token is a network secret on that environment (never in the repo or chat). The token pasted in chat
  on 2026-11-24 must be revoked.
- App name under the icon is "ApneDoctors" on both platforms; Android release builds declare INTERNET.

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
- Sign-in, next: Google needs a Google Cloud OAuth client (free; the founder creates it and shares the client IDs);
  phone OTP needs a paid SMS provider. Google only first, or both?
- How doctors get verified (HPR check, who approves) before any doctor can appear online.
- Connect a Mac to record iOS simulator videos?
