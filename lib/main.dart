import 'package:flutter/material.dart';

import 'services/auth_service.dart';
import 'screens/auth_gate.dart';
import 'screens/start_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Si tu AuthService requiere inicialización global, hacelo acá.
  // await AuthService.instance.init();

  runApp(const App());
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  bool _isLight = true;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF0A84FF),
      brightness: _isLight ? Brightness.light : Brightness.dark,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BitFlow',
      theme: theme,
      home: AuthGate(
        child: StartPage(
          isLight: _isLight,
          onToggleTheme: () {
            setState(() {
              _isLight = !_isLight;
            });
          },
        ),
      ),
    );
  }
}
