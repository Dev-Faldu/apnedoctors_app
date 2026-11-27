// The shared Getting-in widgets, laid out as two pages, at 360x640 and 390x844, text at 100% and 200% (GI-60).
// Regenerate after an approved design change: flutter test --update-goldens test/goldens
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apnedoctors/core/theme/tokens.dart';
import 'package:apnedoctors/shared/widgets/google_button.dart';
import 'package:apnedoctors/shared/widgets/kp_scaffold.dart';
import 'package:apnedoctors/shared/widgets/living_a.dart';
import 'package:apnedoctors/shared/widgets/code_tiles.dart';
import 'package:apnedoctors/shared/widgets/phone_field.dart';
import 'package:apnedoctors/shared/widgets/primary_button.dart';

import '../support/fonts.dart';
import '../support/harness.dart';

const _sizes = [Size(360, 640), Size(390, 844)];
const _scales = [1.0, 2.0];

String _name(Size s, double scale) => '${s.width.toInt()}x${s.height.toInt()}_text${(scale * 100).toInt()}';

Widget _label(String text) => Padding(
  padding: const EdgeInsets.only(top: 20, bottom: 8),
  child: Text(text, style: AdType.hint),
);

/// Fields: the phone number as it is typed, and refused; the code boxes part-filled, and wrong.
Widget galleryFields() => KpScaffold(
  onBack: () {},
  top: const LivingA(mood: AMood.listening, size: 40),
  body: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('your number', style: AdType.headline()),
      _label('Typing'),
      PhoneField(controller: TextEditingController(text: '98765 43210')),
      _label('Not a mobile number (GI-21)'),
      PhoneField(controller: TextEditingController(text: '58765 43210')),
      _label('Code, three digits in'),
      CodeTiles(
        controller: TextEditingController(text: '482'),
        onCompleted: (_) {},
      ),
      _label('Wrong code (GI-25)'),
      CodeTiles(
        controller: TextEditingController(text: '482915'),
        onCompleted: (_) {},
        look: CodeLook.wrong,
      ),
    ],
  ),
  bottom: PrimaryButton(label: 'Send code', onPressed: () {}),
);

/// Buttons and the moods of the living "a".
Widget galleryButtons() => KpScaffold(
  body: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('buttons', style: AdType.headline()),
      _label('Ready'),
      PrimaryButton(label: 'Send code', onPressed: () {}),
      _label('Not ready yet'),
      const PrimaryButton(label: 'Send code', onPressed: null),
      _label('Sending (GI-24)'),
      PrimaryButton(label: 'Send code', onPressed: () {}, loading: true),
      _label('Google'),
      GoogleButton(onPressed: () {}),
      _label('The living a'),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final mood in AMood.values)
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 88),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LivingA(mood: mood, size: 56),
                  const SizedBox(height: 4),
                  Text(mood.name, style: AdType.hint, textAlign: TextAlign.center),
                ],
              ),
            ),
        ],
      ),
    ],
  ),
);

void main() {
  setUpAll(loadAppFonts);

  for (final size in _sizes) {
    for (final scale in _scales) {
      // reduced motion: every widget holds its still pose, so the images are exact
      testWidgets('shared fields ${_name(size, scale)}', (tester) async {
        setPhone(tester, size);
        await tester.pumpWidget(phone(galleryFields(), reducedMotion: true, textScale: scale));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        await expectLater(find.byType(KpScaffold), matchesGoldenFile('shared/fields_${_name(size, scale)}.png'));
      });

      testWidgets('shared buttons ${_name(size, scale)}', (tester) async {
        setPhone(tester, size);
        await tester.pumpWidget(phone(galleryButtons(), reducedMotion: true, textScale: scale));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        await expectLater(find.byType(KpScaffold), matchesGoldenFile('shared/buttons_${_name(size, scale)}.png'));
      });
    }
  }
}
