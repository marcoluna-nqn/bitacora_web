import 'package:flutter/material.dart';

/// Controlador de tema Gridnote (claro/oscuro).
class GridnoteThemeController extends ChangeNotifier {
  GridnoteThemeController({bool light = true}) : _light = light;
  bool _light;

  GridnoteTheme get theme => _build(_light);

  void setLight(bool v) {
    if (_light == v) return;
    _light = v;
    notifyListeners();
  }

  void toggle() => setLight(!_light);

  GridnoteTheme _build(bool light) {
    const blue = Color(0xFF0A84FF);
    final scheme = ColorScheme.fromSeed(
      seedColor: blue,
      brightness: light ? Brightness.light : Brightness.dark,
    );
    final scaffold = light ? const Color(0xFFF2F2F7) : const Color(0xFF0B1220);
    final card = light ? Colors.white : const Color(0xFF0E1624);
    final divider = light ? const Color(0xFFE5E5EA) : const Color(0xFF243043);

    final material = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      cardColor: card,
      dividerColor: divider,
      visualDensity: VisualDensity.compact,
      fontFamilyFallback: const ['SF Pro Text','Inter','Roboto','Segoe UI','Helvetica','Arial'],
    );

    return GridnoteTheme(
      material: material,
      scaffold: scaffold,
      card: card,
      divider: divider,
    );
  }
}

/// Paleta/tema efectivo para Gridnote.
class GridnoteTheme {
  const GridnoteTheme({
    required this.material,
    required this.scaffold,
    required this.card,
    required this.divider,
  });

  final ThemeData material;
  final Color scaffold;
  final Color card;
  final Color divider;
}

/// Estilo de la tabla (encabezado, líneas y celdas) derivado del tema.
class GridnoteTableStyle {
  const GridnoteTableStyle({
    required this.headerBg,
    required this.headerText,
    required this.gridLine,
    required this.cellBg,
  });

  final Color headerBg;
  final Color headerText;
  final Color gridLine;
  final Color cellBg;

  factory GridnoteTableStyle.from(GridnoteTheme g) {
    final isLight = g.material.brightness == Brightness.light;
    return GridnoteTableStyle(
      headerBg: isLight ? const Color(0xFFF9F9FB) : const Color(0xFF111827),
      headerText: isLight ? const Color(0xFF111111) : Colors.white,
      gridLine: g.divider,
      cellBg: g.card,
    );
  }
}
