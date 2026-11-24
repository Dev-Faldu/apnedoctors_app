# ApneDoctors: edge cases

Each case has an ID. Name IDs in tests and commits. A feature is done only when its cases are handled
and tested. `[x]` handled and tested · `[~]` partly · `[ ]` open.

## 1. Launch and device (EC-LAUNCH)
- [x] 01 **First open ever** → full opening into Welcome. (`test/features/launch_test.dart`)
- [ ] 02 **Opened before, signed in** → straight to Today (needs sign-in).
- [x] 04 **App killed mid-opening** → marked as opened when the opening starts; the next launch shows
  Welcome, never the full opening again. (`launch_test.dart`)
- [ ] 05 **Storage cleared, session still in secure storage** → signed-in path (needs sign-in).
- [x] 07 **Reduced motion on** → no opening; Welcome's settled frame, nothing loops. (`launch_test.dart`)
- [x] 08 **Custom font fails** → fonts are bundled, nothing is fetched at runtime; the system font is the fallback.
- [ ] 09 **Low-end Android (2 GB RAM)** → opening stays smooth; profile on a real device.
- [x] 11 **Slow or no network at launch** → nothing waits for the network: the backend starts from local storage,
  the doctors count arrives when it can; offline means no chip, no error. (`test/features/doctors_online_test.dart`)
- [x] 12 **Backgrounded mid-opening** → finishes instantly on return; no frozen half-states.
  (`test/features/opening_screen_test.dart`)
- [ ] 13 **Cold start from a push** → skip the long opening (needs push).
- [x] 16 **Tablets, landscape** → phones are portrait-locked; tablets may rotate (layout pass needed for tablets).
- [x] 17 **System dark mode** → the app keeps its own palette; the native splash is paper in dark mode too.
- [x] 18 **Tap during the opening** → fast-forwards smoothly to Welcome in about 0.6 s. (`opening_screen_test.dart`)

## 2. Accessibility and layout (EC-A11Y)
- [x] 01 **Text at 200%** → no clipped or overflowing text at 320×568, 360×640, 390×844; headline
  capped at 1.3×, top bar labels at 1.5×, the page scrolls. (`opening_screen_test.dart`)
- [x] 02 **Screen reader** → brand, doorway, headline (header), chip and every button labelled.
- [x] 03 **Contrast** → body #4A3F36 and ink on paper, white on vermilion: WCAG AA.
- [x] 04 **Touch targets** → at least 48 × 48. (`opening_screen_test.dart`)
- [x] 05 **Small phones** → checked at 320×568 and 360×640; the buttons stay visible.

## 3. Backend and infrastructure (EC-INFRA)
- [x] 01 **Backend unreachable after a count was shown** → the last count stays up to 2 minutes (a doctor's
  presence lasts that long), then the chip goes away. (`doctors_online_test.dart`)
- [x] 02 **Live data changes mid-animation** → the chip never appears or vanishes during the hand-off; after Welcome
  settles it slides in or out. (`opening_screen_test.dart`)
- [x] 03 **Shipped migration edited** → `supabase/deploy.py` refuses to run; add a new migration instead.
- [ ] 04 **Supabase outage during sign-in** → (with sign-in).

## 4. Security (EC-SEC)
- [x] 01 **Every table has row-level security**, checked in tests and on the live project.
- [x] 02 **The public can run only `doctors_online()`**; signed-in people also `set_doctor_presence()`, which
  refuses anyone who is not a verified doctor. (`supabase/tests/test_database.py`, live check)
- [x] 03 **Internals stay internal**: the `private` schema is closed; Supabase's `rls_auto_enable()` is not callable.
- [x] 04 **Nobody outside the server writes doctors or presence** (anon and signed-in both refused; live too).
- [x] 05 **The doctors directory is not public**: only a doctor's own entry is readable, by that doctor.
- [x] 06 **No account door the product didn't choose**: email sign-up and anonymous accounts are off (live check).
- [x] 07 **No secrets in the repo**: only the public URL and publishable key; the access token lives in the cloud
  environment's network secrets.

## 5. Content honesty (EC-COPY)
- [x] 01 **No made-up numbers** → the "doctors online" chip shows only a real, live count of verified doctors
  above zero, from the backend. (`opening_screen_test.dart`, `doctors_online_test.dart`, `test_database.py`)
