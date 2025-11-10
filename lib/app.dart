// lib/app.dart
import 'package:flutter/material.dart';
import 'theme/gridnote_theme.dart';
import 'screens/start_page.dart';
import 'screens/auth_gate.dart'; // <-- agrega esto

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
          home: AuthGate(
            child: StartPage(
              isLight: g.material.brightness == Brightness.light,
              onToggleTheme: _toggleTheme,
            ),
          ),
        );
      },
    );
  }
}
