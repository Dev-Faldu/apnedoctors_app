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
- [ ] 11 **Very slow network** → the opening never waits for the network (true today; keep it so).
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

## 3. Content honesty (EC-COPY)
- [x] 01 **No made-up numbers** → the "doctors online" chip shows only a real count above zero.
  (`opening_screen_test.dart`)
