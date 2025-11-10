// lib/main.dart
import 'dart:async' show unawaited;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'theme/gridnote_theme.dart';
import 'screens/start_page.dart';
import 'services/google_auth.dart';

@pragma('vm:entry-point')
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Mostrar errores en vez de pantalla blanca.
  FlutterError.onError = (FlutterErrorDetails d) {
    FlutterError.presentError(d);
    if (kDebugMode) {
      // Log útil en Chrome DevTools (F12 → Console)
      // ignore: avoid_print
      print('FlutterError: ${d.exception}\n${d.stack}');
    }
  };
  ErrorWidget.builder = (details) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Error: ${details.exception}',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );

  // Google OAuth: no bloquea la UI si falla.
  unawaited(GoogleAuthService.I.init(
    clientId: const String.fromEnvironment(
      'GSI_WEB_CLIENT_ID',
      defaultValue: 'TU_CLIENT_ID_WEB.apps.googleusercontent.com',
    ),
    // serverClientId: 'OPCIONAL_CLIENT_ID_ANDROID_O_IOS.apps.googleusercontent.com',
  ));

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GridnoteThemeController _theme = GridnoteThemeController(light: true);
  void _toggleTheme() => _theme.toggle();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _theme,
      builder: (_, __) {
        final g = _theme.theme;
        return MaterialApp(
          title: 'Bitácora Web',
          debugShowCheckedModeBanner: false,
          theme: g.material,
          // Mostramos SIEMPRE la StartPage. El login se prueba después.
          home: StartPage(
            isLight: g.material.brightness == Brightness.light,
            onToggleTheme: _toggleTheme,
          ),
        );
      },
    );
  }
}
