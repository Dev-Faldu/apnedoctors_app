# Design compare

Checks the app against the design boards in `docs/design/kalighat-pop/`, frame by frame.

Run from `apps/patient` (needs `pip install uharfbuzz fonttools brotli pillow`, Node with Playwright, ffmpeg):

```bash
W=/tmp/adcompare
python3 tool/design_compare/make_board_pages.py $W                                  # board as offline pages
node tool/design_compare/board_frames.js $W splash.html $W/frames/board 60 0 10.5   # board frames
flutter test tool/frames/capture_test.dart --dart-define=OUT=$W/frames/app           # app frames
python3 tool/design_compare/compare.py $W/frames/board $W/frames/app $W/cmp 0.55 3.4,6.0,10.0
```

- `board_frames.js` pauses every CSS animation and seeks it to each timestamp, so frames are exact.
- `capture_test.dart` renders the real `OpeningScreen` with Flutter's test renderer at the same timestamps.
- `compare.py` writes per-frame diff stats (`stats.tsv`) and side-by-side sheets (board, app, diff x4).
- `measure.js` prints the board's element boxes (what the layout tests in `test/features` assert).
- `splash_png.js` renders the native-splash images in `assets/brand/`.

The first 0.55 s differ on purpose: the board starts from a home-screen icon; on a phone the OS
animates the icon and the native splash hands over to the app's first frame.
