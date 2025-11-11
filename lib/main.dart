import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';

import 'services/auth_service.dart';
import 'screens/auth_gate.dart';
import 'screens/start_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      title: 'Bit Flow',
      theme: theme,
      scrollBehavior: const _AppScrollBehavior(),
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

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => <PointerDeviceKind>{
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.unknown,
  };

  // Si tu versión de Flutter admite este override, te da rebote tipo iOS.
  // Si te da error de compilación, borrá TODO este método y dejá solo dragDevices.
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    final platform = getPlatform(context);
    if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
      return const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      );
    }
    return const ClampingScrollPhysics();
  }
}
