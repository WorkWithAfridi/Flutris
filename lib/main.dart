import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import 'ui/handheld_screen.dart';
import 'ui/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0x00000000),
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Color(0x00000000),
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Color(0x00000000),
      systemNavigationBarContrastEnforced: false,
    ),
  );
  runApp(const FlutrisApp());
}

class FlutrisApp extends StatelessWidget {
  const FlutrisApp({super.key, this.showSplash = true});

  /// Set to false in tests to go straight to the handheld UI.
  final bool showSplash;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: DefaultTextStyle(
        style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF302449)),
        child: showSplash
            ? const SplashScreen(child: HandheldScreen())
            : const HandheldScreen(),
      ),
    );
  }
}
