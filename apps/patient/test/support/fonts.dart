import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apnedoctors/core/theme/tokens.dart';

bool _loaded = false;

/// Loads the bundled fonts into the test engine so goldens show real type, not the test font.
Future<void> loadAppFonts() async {
  if (_loaded) return;
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final (family, file) in const [
    (AdFonts.anek, 'assets/fonts/AnekLatin-Variable.ttf'),
    (AdFonts.anekExt, 'assets/fonts/AnekLatinExt-Variable.ttf'),
    (AdFonts.kaushan, 'assets/fonts/KaushanScript-Regular.ttf'),
    (AdFonts.roboto, 'assets/fonts/Roboto-Medium.ttf'),
  ]) {
    await (FontLoader(family)..addFont(rootBundle.load(file))).load();
  }
  _loaded = true;
}
