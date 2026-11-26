import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apnedoctors/core/theme/tokens.dart';
import 'package:apnedoctors/shared/indian_phone.dart';
import 'package:apnedoctors/shared/widgets/google_button.dart';
import 'package:apnedoctors/shared/widgets/kp_icons.dart';
import 'package:apnedoctors/shared/widgets/kp_scaffold.dart';
import 'package:apnedoctors/shared/widgets/living_a.dart';
import 'package:apnedoctors/shared/widgets/otp_boxes.dart';
import 'package:apnedoctors/shared/widgets/phone_field.dart';
import 'package:apnedoctors/shared/widgets/primary_button.dart';

import '../support/fonts.dart';
import '../support/get_started_driver.dart' show phoneInput;
import '../support/harness.dart';

Widget pad(Widget child) => Padding(
  padding: const EdgeInsets.all(24),
  child: Align(alignment: Alignment.topCenter, child: child),
);

void main() {
  setUpAll(loadAppFonts);

  group('PhoneField', () {
    Future<(TextEditingController, List<PhoneParse>)> field(WidgetTester tester, {bool reduced = true}) async {
      setPhone(tester, const Size(390, 844));
      final c = TextEditingController();
      final seen = <PhoneParse>[];
      await tester.pumpWidget(
        phone(
          pad(PhoneField(controller: c, onChanged: seen.add)),
          reducedMotion: reduced,
        ),
      );
      return (c, seen);
    }

    RenderDigitSlots slots(WidgetTester tester) => tester.renderObject<RenderDigitSlots>(find.byType(DigitSlots));

    testWidgets('GI-20: typed digits group as 98765 43210, parse to +91, and the tick pops in', (tester) async {
      final (c, seen) = await field(tester);
      await tester.enterText(phoneInput, '9876543210');
      await tester.pump();
      expect(c.text, '98765 43210');
      expect((seen.last as PhoneOk).e164, '+919876543210');
      expect(findParagraph('We’ll text a 6-digit code to this number.'), findsOneWidget);
      expect(
        tester
            .widget<AnimatedScale>(find.ancestor(of: find.byType(TickMark), matching: find.byType(AnimatedScale)))
            .scale,
        1,
      );
    });

    testWidgets('the empty field shows ten dots; each digit takes one dot\'s place', (tester) async {
      final (_, _) = await field(tester);
      expect(tester.widget<DigitSlots>(find.byType(DigitSlots)).digits, '');
      await tester.enterText(phoneInput, '98765');
      await tester.pump();
      expect(tester.widget<DigitSlots>(find.byType(DigitSlots)).digits, '98765');
      expect(slots(tester).size.width, greaterThan(0));
    });

    testWidgets('digits drop into their slots (and a paste fills slot after slot)', (tester) async {
      final (_, _) = await field(tester, reduced: false);
      await tester.enterText(phoneInput, '9876543210');
      await tester.pump();
      final born = tester.widget<DigitSlots>(find.byType(DigitSlots)).born;
      expect(born[9], greaterThan(born[0])); // staggered
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('GI-22: a pasted +91 number with spaces lands as ten digits', (tester) async {
      final (c, _) = await field(tester);
      await tester.enterText(phoneInput, '+91 98765-43210');
      expect(c.text, '98765 43210');
      await tester.enterText(phoneInput, '098765 43210');
      expect(c.text, '98765 43210');
    });

    testWidgets('GI-21: a first digit of 0–5 is called out at once, with what a mobile looks like', (tester) async {
      final (_, seen) = await field(tester);
      await tester.enterText(phoneInput, '5');
      await tester.pump();
      expect(findParagraph(phoneStartHint), findsOneWidget);
      expect((seen.last as PhoneBad).problem, PhoneProblem.notAMobile);
    });

    testWidgets('GI-21: no complaint while a good number is still being typed', (tester) async {
      await field(tester);
      await tester.enterText(phoneInput, '98765');
      await tester.pump();
      expect(findParagraph(phoneStartHint), findsNothing);
      expect(find.byType(AlertMark), findsNothing);
    });

    testWidgets('GI-23: another country\'s number is refused in plain words', (tester) async {
      final (c, seen) = await field(tester);
      await tester.enterText(phoneInput, '+1 415 555 0100');
      await tester.pump();
      expect(c.text, '');
      expect(findParagraph('For now we can only send codes to Indian mobile numbers.'), findsOneWidget);
      expect((seen.last as PhoneBad).problem, PhoneProblem.notIndian);
    });

    testWidgets('GI-60: at 200% text on a small phone the whole number still fits on one line', (tester) async {
      setPhone(tester, const Size(360, 640));
      await tester.pumpWidget(
        phone(pad(PhoneField(controller: TextEditingController(text: '98765 43210'))), textScale: 2),
      );
      expect(tester.takeException(), isNull);
      final box = tester.getRect(find.byType(DigitSlots));
      final field = tester.getRect(find.byType(PhoneField));
      expect(box.right, lessThan(field.right));
      expect(box.height, greaterThanOrEqualTo(24 * 1.25));
    });

    testWidgets('GI-61: screen readers hear what the field is for', (tester) async {
      final handle = tester.ensureSemantics();
      await field(tester);
      expect(find.bySemanticsLabel(RegExp('Mobile number, plus 91')), findsOneWidget);
      handle.dispose();
    });
  });

  group('OtpBoxes', () {
    testWidgets('submits once when the sixth digit lands, again only for a different code', (tester) async {
      setPhone(tester, const Size(390, 844));
      final c = TextEditingController();
      final codes = <String>[];
      await tester.pumpWidget(phone(pad(OtpBoxes(controller: c, onCompleted: codes.add))));
      await tester.enterText(find.byType(EditableText), '12345');
      expect(codes, isEmpty);
      await tester.enterText(find.byType(EditableText), '123456');
      await tester.pump();
      c.text = '123456'; // the same code again (autofill firing twice) is ignored
      await tester.pump();
      expect(codes, ['123456']);
      await tester.enterText(find.byType(EditableText), '12345');
      await tester.enterText(find.byType(EditableText), '123457');
      expect(codes, ['123456', '123457']);
    });

    testWidgets('a pasted code fills every box; letters never get in', (tester) async {
      setPhone(tester, const Size(390, 844));
      final c = TextEditingController();
      await tester.pumpWidget(phone(pad(OtpBoxes(controller: c, onCompleted: (_) {}))));
      await tester.enterText(find.byType(EditableText), '98a76b5432');
      await tester.pump();
      expect(c.text, '987654');
      for (final d in ['9', '8', '7', '6', '5', '4']) {
        expect(find.text(d), findsOneWidget);
      }
    });

    testWidgets('GI-25: a wrong code shakes the boxes, and the same code can be tried again', (tester) async {
      setPhone(tester, const Size(390, 844));
      final c = TextEditingController();
      final codes = <String>[];
      Widget boxes(int errors) =>
          phone(pad(OtpBoxes(controller: c, onCompleted: codes.add, error: errors > 0, errorCount: errors)));
      await tester.pumpWidget(boxes(0));
      await tester.enterText(find.byType(EditableText), '111111');
      await tester.pumpWidget(boxes(1));
      await tester.pump(const Duration(milliseconds: 60));
      final shifted = tester.widget<Transform>(
        find.descendant(of: find.byType(OtpBoxes), matching: find.byType(Transform)).first,
      );
      expect(shifted.transform.getTranslation().x, isNot(0));
      await tester.pump(const Duration(milliseconds: 500));
      c.text = '111111';
      await tester.pump();
      expect(codes, ['111111', '111111']);
    });

    testWidgets('GI-60: at 200% text on a small phone each digit keeps air inside its box', (tester) async {
      setPhone(tester, const Size(360, 640));
      await tester.pumpWidget(
        phone(
          pad(
            OtpBoxes(
              controller: TextEditingController(text: '888888'),
              onCompleted: (_) {},
            ),
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      final digit = tester.getSize(find.text('8').first);
      final box = tester.getSize(
        find.ancestor(of: find.text('8').first, matching: find.byType(AnimatedContainer)).first,
      );
      expect(box.width - digit.width, greaterThanOrEqualTo(16));
      expect(digit.height, greaterThan(28 * 1.1 * 1.4)); // grown well past 100%, only capped to fit
    });

    testWidgets('GI-61: the six boxes read as one field', (tester) async {
      setPhone(tester, const Size(390, 844));
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(phone(pad(OtpBoxes(controller: TextEditingController(), onCompleted: (_) {}))));
      expect(find.bySemanticsLabel('6-digit code'), findsOneWidget);
      handle.dispose();
    });
  });

  group('PrimaryButton', () {
    testWidgets('GI-24: a double tap while sending sends once', (tester) async {
      setPhone(tester, const Size(390, 844));
      var sends = 0;
      var loading = false;
      await tester.pumpWidget(
        phone(
          StatefulBuilder(
            builder: (context, setState) => pad(
              PrimaryButton(
                label: 'Send code',
                loading: loading,
                onPressed: () => setState(() {
                  sends++;
                  loading = true;
                }),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();
      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();
      expect(sends, 1);
    });

    testWidgets('disabled until it can do something, and says so to screen readers', (tester) async {
      setPhone(tester, const Size(390, 844));
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(phone(pad(const PrimaryButton(label: 'Send code', onPressed: null))));
      expect(
        tester.getSemantics(find.byType(PrimaryButton)),
        matchesSemantics(label: 'Send code', isButton: true, hasEnabledState: true),
      );
      handle.dispose();
    });

    testWidgets('GI-60: at 200% text it grows taller instead of clipping', (tester) async {
      setPhone(tester, const Size(360, 640));
      await tester.pumpWidget(
        phone(pad(PrimaryButton(label: 'Continue as +91 98•••••210', onPressed: () {})), textScale: 2),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(PrimaryButton)).height, greaterThan(56));
    });
  });

  group('GoogleButton', () {
    testWidgets('Google\'s own G, the app\'s type and a quiet outline; reports taps', (tester) async {
      setPhone(tester, const Size(390, 844));
      var taps = 0;
      await tester.pumpWidget(phone(pad(GoogleButton(onPressed: () => taps++))));
      await tester.tap(find.byType(GoogleButton));
      expect(taps, 1);
      final label = tester.widget<Text>(find.text('Continue with Google'));
      expect(label.style!.fontFamily, AdFonts.anek);
      final box = tester.widget<Container>(
        find.descendant(of: find.byType(GoogleButton), matching: find.byType(Container)),
      );
      final d = box.decoration! as BoxDecoration;
      expect(d.color, AdColors.white);
      expect((d.border! as Border).top.color, AdColors.fieldBorder);
    });
  });

  group('LivingA', () {
    for (final mood in AMood.values) {
      testWidgets('draws ${mood.name} and moves on to the next mood smoothly', (tester) async {
        setPhone(tester, const Size(390, 844));
        await tester.pumpWidget(phone(pad(LivingA(mood: mood))));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpWidget(phone(pad(const LivingA(mood: AMood.breathing))));
        await tester.pump(const Duration(milliseconds: 120));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('GI-62: with reduced motion it holds still (nothing left ticking)', (tester) async {
      setPhone(tester, const Size(390, 844));
      await tester.pumpWidget(phone(pad(const LivingA(mood: AMood.celebrating)), reducedMotion: true));
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('GI-61: decorative unless it means something', (tester) async {
      setPhone(tester, const Size(390, 844));
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(phone(pad(const LivingA())));
      expect(find.bySemanticsLabel(RegExp('.')), findsNothing);
      await tester.pumpWidget(phone(pad(const LivingA(semanticLabel: 'The a is listening'))));
      expect(find.bySemanticsLabel('The a is listening'), findsOneWidget);
      handle.dispose();
    });
  });

  group('KpScaffold', () {
    testWidgets('GI-63: on a small phone with the keyboard open the main action stays above it', (tester) async {
      setPhone(tester, const Size(360, 640));
      await tester.pumpWidget(
        phone(
          MediaQuery(
            data: const MediaQueryData(size: Size(360, 640), viewInsets: EdgeInsets.only(bottom: 300)),
            child: KpScaffold(
              onBack: () {},
              body: Column(children: [for (var i = 0; i < 12; i++) const Text('A line of the screen')]),
              bottom: PrimaryButton(label: 'Send code', onPressed: () {}),
            ),
          ),
        ),
      );
      final button = tester.getRect(find.byType(PrimaryButton));
      expect(button.bottom, lessThanOrEqualTo(640 - 300));
      expect(button.top, greaterThan(56));
    });

    testWidgets('GI-64: the back chevron is a 48 × 48 button that goes back', (tester) async {
      setPhone(tester, const Size(360, 640));
      var back = 0;
      await tester.pumpWidget(phone(KpScaffold(onBack: () => back++, body: const SizedBox())));
      expect(tester.getSize(find.byType(BackChevron)), const Size(48, 48));
      await tester.tap(find.byType(BackChevron));
      expect(back, 1);
    });

    testWidgets('GI-60: at 200% text the body scrolls instead of clipping', (tester) async {
      setPhone(tester, const Size(360, 640));
      await tester.pumpWidget(
        phone(
          KpScaffold(
            body: Column(
              children: [for (var i = 0; i < 20; i++) Text('Line $i of a long screen', style: AdType.lede())],
            ),
            bottom: PrimaryButton(label: 'Send code', onPressed: () {}),
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(Scrollable), findsOneWidget);
      expect(tester.renderObject<RenderBox>(find.byType(PrimaryButton)).hasSize, isTrue);
    });
  });
}
