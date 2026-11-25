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

  // avatar tints on the "doctors online" chip
  static const avatarIndigo = Color(0xFFDCE3F5);
  static const avatarRose = Color(0xFFF9D9D6);
  static const avatarLeaf = Color(0xFFD7EBD3);
}

abstract final class AdFonts {
  static const anek = 'AnekLatin';
  static const anekExt = 'AnekLatinExt';
  static const kaushan = 'KaushanScript';

  /// Only inside the Google button, as Google's branding rules ask.
  static const roboto = 'Roboto';
}

/// Google's sign-in button colours (light theme, neutral), as their branding guidelines set them.
abstract final class GoogleBrand {
  static const fill = Color(0xFFFFFFFF);
  static const stroke = Color(0xFF747775);
  static const text = Color(0xFF1F1F1F);
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
  static const google = TextStyle(
    fontFamily: AdFonts.roboto,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.25,
    color: GoogleBrand.text,
  );
}

abstract final class AdSpace {
  static const side = 24.0; // every screen's side margin
}
