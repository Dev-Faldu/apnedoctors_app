import 'package:flutter/painting.dart';

/// Every colour, type style and size of the app lives here. No ad-hoc values anywhere else.
///
/// Design: "Kalighat pop" (docs/design/kalighat-pop). Values are the board's CSS values.
abstract final class AdColors {
  static const paper = Color(0xFFFBF7EF);
  static const paperClear = Color(0x00FBF7EF); // paper at 0 alpha, for fades into paper
  static const vermilion = Color(0xFFC8302B); // brand, primary
  static const ink = Color(0xFF1A1410);
  static const haldi = Color(0xFFEFB12A); // turmeric
  static const green = Color(0xFF62A65A);
  static const indigo = Color(0xFF5674C4);
  static const heart = Color(0xFFE0484E);

  // supporting tones from kp.css
  static const body = Color(0xFF4A3F36);
  static const muted = Color(0xFF6B5E52);
  static const line = Color(0xFFE8DFD1);
  static const pink = Color(0xFFF59AA0);
  static const white = Color(0xFFFFFFFF);

  // doorway (N01Welcome)
  static const doorwayTop = Color(0xFFFFE9D2);
  static const doorwayBottom = Color(0xFFFFF6EC);
  static const marigold = Color(0xFFF08A2B);
  static const toranString = Color(0xFF7A4B12);

  // fields and quiet states (kp.css .field, .btn.off)
  static const fieldBorder = Color(0xFFD9CDBA);
  static const disabledFill = Color(0xFFE8DFD1);
  static const focusRing = Color(0x24C8302B); // vermilion at 14%

  // Get started (G03): field states, tick, error text
  static const placeholder = Color(0xFF9A8D7C); // typed-text hint, never body copy
  static const lockedFill = Color(0xFFF4EEE4); // a field or button that can't be used right now
  static const lockedBorder = Color(0xFFE3D9C9);
  static const ring = Color(0x1FC8302B); // vermilion at 12%, around a focused or wrong field
  static const errorText = Color(0xFFA3221D); // deep vermilion: 6.6:1 on paper
  static const tick = Color(0xFF3F7F38); // "looks right": 4.9:1 against white
  static const okFill = Color(0xFFEEF6EC); // a verified code's tiles
  static const okText = Color(0xFF2F6A29); // on okFill: 5.9:1

  // avatar tints on the "doctors online" chip
  static const avatarIndigo = Color(0xFFDCE3F5);
  static const avatarRose = Color(0xFFF9D9D6);
  static const avatarLeaf = Color(0xFFD7EBD3);
}

abstract final class AdFonts {
  static const anek = 'AnekLatin';
  static const anekExt = 'AnekLatinExt';
  static const kaushan = 'KaushanScript';
}

/// The colours of Google's "G", as their branding guidelines set them.
abstract final class GoogleBrand {
  static const blue = Color(0xFF4285F4);
  static const red = Color(0xFFEA4335);
  static const yellow = Color(0xFFFBBC05);
  static const green = Color(0xFF34A853);
}

/// Anek Latin is a variable font (wght 100–800, wdth 75–125, default wght 500), so every style sets
/// its axes explicitly. CSS `font-stretch: 112%` is `wdth 112`.
TextStyle anek({
  required double size,
  double weight = 400,
  double width = 100,
  double? height,
  double letterSpacing = 0,
  Color color = AdColors.ink,
}) {
  return TextStyle(
    fontFamily: AdFonts.anek,
    fontFamilyFallback: const [AdFonts.anekExt],
    fontSize: size,
    fontWeight: FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)],
    fontVariations: [FontVariation('wght', weight), FontVariation('wdth', width)],
    height: height,
    leadingDistribution: TextLeadingDistribution.even, // CSS half-leading
    letterSpacing: letterSpacing,
    color: color,
  );
}

abstract final class AdType {
  /// Welcome headline: 50px, line-height .94, letter-spacing -1.6, width 112%, weight 800.
  static TextStyle display({bool compact = false}) =>
      anek(size: compact ? 40 : 50, weight: 800, width: 112, height: .94, letterSpacing: -1.6);

  /// Body copy (`.lede`): 17px / 1.45, body ink. 16px on short screens.
  static TextStyle lede({bool compact = false}) => anek(size: compact ? 16 : 17, height: 1.45, color: AdColors.body);

  static final button = anek(size: 19, weight: 800, width: 110, height: 21 / 19, color: AdColors.white);
  static final link = anek(size: 15, weight: 700, height: 17 / 15);
  static final linkUnderlined = link.copyWith(decoration: TextDecoration.underline, decorationColor: AdColors.ink);
  static final chip = anek(size: 15, weight: 700, height: 17 / 15);
  static final avatar = anek(size: 11, weight: 800, height: 1);
  static final bubble = anek(size: 16, weight: 800, height: 1);

  /// Screen headlines below Welcome's (lowercase, as on Welcome): 34px, wide and heavy.
  static TextStyle headline({bool compact = false}) =>
      anek(size: compact ? 30 : 34, weight: 800, width: 112, height: 1.02, letterSpacing: -.8);

  /// Typed into fields (kp.css .field): 19px, weight 600.
  static final field = anek(size: 19, weight: 600, height: 1.2);
  static final fieldPrefix = anek(size: 19, weight: 700, height: 1.2);
  static final otpDigit = anek(size: 28, weight: 800, width: 100, height: 1.1);

  /// Errors and hints under a field: 16px so they are body-size readable.
  static final error = anek(size: 16, weight: 600, height: 1.35, color: AdColors.vermilion);
  static final hint = anek(size: 16, height: 1.35, color: AdColors.muted);
  static final buttonDisabled = anek(size: 19, weight: 800, width: 110, height: 21 / 19, color: AdColors.muted);
}

/// Get started (G03) and the screens built on kp.css `.btn`, `.field`, `.lab`.
abstract final class KpType {
  /// The screen headline: 46 px / .94, wide and heavy. 36 px on a short phone with the keyboard open.
  static TextStyle h1({bool compact = false}) =>
      anek(size: compact ? 36 : 46, weight: 800, width: 112, height: .94, letterSpacing: compact ? -1 : -1.4);

  /// A field's label: 14 px bold, muted.
  static final label = anek(size: 14, weight: 700, height: 16 / 14, color: AdColors.muted);

  /// The +91 in the phone field.
  static final countryCode = anek(size: 20, weight: 700, width: 105, height: 22 / 20);

  /// Digits of the phone number, each drawn in its own slot.
  static final digits = anek(size: 24, weight: 600, width: 104, height: 1.25);

  /// A digit in a code tile.
  static final codeDigit = anek(size: 30, weight: 800, width: 105, height: 1.15);

  /// The number in the "sent to" pill.
  static final pillNumber = anek(size: 17, weight: 700, height: 1.2);
  static final pillAction = anek(size: 15, weight: 800, height: 1.2, color: AdColors.vermilion);

  /// A row title in a choices card ("Send it again") and its quiet second line.
  static final rowTitle = anek(size: 17, weight: 700, height: 1.25);
  static final rowSub = anek(size: 14, height: 1.35, color: AdColors.muted);
  static final cardTitle = anek(size: 15, weight: 800, height: 1.2);

  /// A good outcome under a field ("Verified").
  static final helpGood = anek(size: 16, weight: 700, height: 1.35, color: AdColors.okText);

  /// The line under a field: body size, so it reads as easily as the rest.
  static final help = anek(size: 16, height: 1.35, color: AdColors.muted);
  static final helpBad = anek(size: 16, weight: 600, height: 1.35, color: AdColors.errorText);

  /// kp.css `.btn`: 18 px, heavy and wide.
  static final button = anek(size: 18, weight: 800, width: 110, height: 20 / 18, color: AdColors.white);
  static final buttonOff = button.copyWith(color: AdColors.muted);

  /// The Google button's label: 17 px bold, normal width.
  static final google = anek(size: 17, weight: 700, height: 19 / 17);

  /// The "or" between the two ways in.
  static final or = anek(size: 14, weight: 700, height: 16 / 14, color: AdColors.muted);

  /// The fine print and its links.
  static final terms = anek(size: 14, height: 1.45, color: AdColors.muted);
  static final termsLink = terms.copyWith(
    color: AdColors.ink,
    fontWeight: FontWeight.w700,
    fontVariations: const [FontVariation('wght', 700), FontVariation('wdth', 100)],
    decoration: TextDecoration.underline,
    decorationColor: AdColors.ink,
  );

  /// "Already have an account? Sign in": the question quiet, the way in strong.
  static final signIn = anek(size: 16, weight: 600, height: 1.25, color: AdColors.body);
  static final signInStrong = anek(size: 16, weight: 800, height: 1.25, color: AdColors.vermilion);

  /// The ink pill that slides in when the phone is offline.
  static final offline = anek(size: 15, weight: 700, height: 1.3, color: AdColors.paper);
}

abstract final class AdSpace {
  static const side = 24.0; // every screen's side margin
}
