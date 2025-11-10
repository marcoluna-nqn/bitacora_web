// lib/theme/gridnote_theme.dart
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
      fontFamilyFallback: const [
        'SF Pro Text',
        'Inter',
        'Roboto',
        'Segoe UI',
        'Helvetica',
        'Arial',
      ],
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
/// Incluye `zebra` y `zebraColor` para compatibilidad con SmartDataSource.
@immutable
class GridnoteTableStyle {
  const GridnoteTableStyle({
    // Nuevos (para SmartDataSource):
    this.zebra = true,
    this.zebraColor = const Color(0x0C000000),

    // Existentes en tu versión:
    required this.headerBg,
    required this.headerText,
    required this.gridLine,
    required this.cellBg,

    // Opcionales extra por si querés tipografías personalizadas:
    this.cellTextStyle,
    this.headerTextStyle,
  });

  /// Rayado alternado de filas.
  final bool zebra;

  /// Color de fondo para filas “zebra”.
  final Color zebraColor;

  /// Fondo de encabezado.
  final Color headerBg;

  /// Color de texto del encabezado.
  final Color headerText;

  /// Color de líneas de la grilla.
  final Color gridLine;

  /// Fondo de celdas.
  final Color cellBg;

  /// (Opcional) Estilo de texto de celda.
  final TextStyle? cellTextStyle;

  /// (Opcional) Estilo de texto de encabezado.
  final TextStyle? headerTextStyle;

  /// Crea el estilo derivado del tema global.
  factory GridnoteTableStyle.from(GridnoteTheme g) {
    final isLight = g.material.brightness == Brightness.light;
    return GridnoteTableStyle(
      zebra: true,
      zebraColor: isLight ? const Color(0x0F000000) : const Color(0x14000000),
      headerBg: isLight ? const Color(0xFFF9F9FB) : const Color(0xFF111827),
      headerText: isLight ? const Color(0xFF111111) : Colors.white,
      gridLine: g.divider,
      cellBg: g.card,
      cellTextStyle: g.material.textTheme.bodyMedium,
      headerTextStyle: g.material.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
  }

  GridnoteTableStyle copyWith({
    bool? zebra,
    Color? zebraColor,
    Color? headerBg,
    Color? headerText,
    Color? gridLine,
    Color? cellBg,
    TextStyle? cellTextStyle,
    TextStyle? headerTextStyle,
  }) {
    return GridnoteTableStyle(
      zebra: zebra ?? this.zebra,
      zebraColor: zebraColor ?? this.zebraColor,
      headerBg: headerBg ?? this.headerBg,
      headerText: headerText ?? this.headerText,
      gridLine: gridLine ?? this.gridLine,
      cellBg: cellBg ?? this.cellBg,
      cellTextStyle: cellTextStyle ?? this.cellTextStyle,
      headerTextStyle: headerTextStyle ?? this.headerTextStyle,
    );
  }
}
