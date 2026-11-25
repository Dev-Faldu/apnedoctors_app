import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/backend/backend.dart';
import 'core/theme/tokens.dart';
import 'features/launch/launch_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicences();

  // Paper all the way to the edges, dark status bar icons, like the native splash.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0x00000000),
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: AdColors.paper,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  // Phones stay portrait; tablets may rotate (EC-LAUNCH-16).
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  if (view.physicalSize.shortestSide / view.devicePixelRatio < 600) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  await connectBackend();
  final store = PrefsLaunchStore(await SharedPreferences.getInstance());
  final kind = store.openedBefore ? LaunchKind.returning : LaunchKind.firstOpen;

  runApp(
    ProviderScope(
      overrides: [launchStoreProvider.overrideWithValue(store), launchKindProvider.overrideWithValue(kind)],
      child: const ApneDoctorsApp(),
    ),
  );
}

void _registerFontLicences() {
  LicenseRegistry.addLicense(() async* {
    for (final f in const [
      ('Anek Latin', 'assets/fonts/OFL-AnekLatin.txt'),
      ('Kaushan Script', 'assets/fonts/OFL-KaushanScript.txt'),
      ('Roboto', 'assets/fonts/OFL-Roboto.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([f.$1], await rootBundle.loadString(f.$2));
    }
  });
}
