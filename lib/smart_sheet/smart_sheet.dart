import 'dart:async';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:flutter/services.dart';

// Import the Gridnote theme so the table matches the existing app aesthetic.
import 'package:bitacora_web/theme/gridnote_theme.dart';

// Local imports for the smart sheet.
import 'smart_datasource.dart';
import 'export_xlsx_service.dart';
import 'validators.dart';
import 'suggestions.dart';

/// Hoja de cálculo avanzada.
///
/// Esta clase construye una grilla editable basada en `SfDataGrid` de Syncfusion
/// con comportamiento similar a una planilla de cálculo. Permite agregar y
/// borrar filas, valida datos numéricos, calcula totales al pie, ofrece
/// sugerencias al crear nuevas filas y exporta a XLSX con auto‐ajuste de
/// columnas. El estilo respeta la paleta Gridnote.
class SmartSheet extends StatefulWidget {
  /// Controlador de tema para sincronizar con la UI principal.
  final GridnoteThemeController theme;

  /// Encabezados iniciales. Si están vacíos se mostrarán como "Col X".
  final List<String> initialHeaders;

  /// Filas iniciales de datos. Se hace una copia para evitar mutación externa.
  final List<List<dynamic>> initialRows;

  /// Nombre de la hoja, usado al exportar.
  final String sheetName;

  const SmartSheet({
    Key? key,
    required this.theme,
    required this.initialHeaders,
    required this.initialRows,
    this.sheetName = 'Hoja inteligente',
  }) : super(key: key);

  @override
  State<SmartSheet> createState() => _SmartSheetState();
}

class _SmartSheetState extends State<SmartSheet> {
  late List<String> _headers;
  late List<List<dynamic>> _rows;
  late SmartDataSource _dataSource;
  late List<double?> _totals;
  final GlobalKey<SfDataGridState> _gridKey = GlobalKey<SfDataGridState>();

  @override
  void initState() {
    super.initState();
    // Copiar datos iniciales para que este widget sea autónomo.
    _headers = List<String>.from(widget.initialHeaders);
    _rows = widget.initialRows
        .map((r) => List<dynamic>.from(r)..length = _headers.length)
        .toList();
    // Asegurar al menos una fila vacía si no se pasa ninguna.
    if (_rows.isEmpty) {
      _rows = [List<dynamic>.filled(_headers.length, '')];
    }
    _dataSource = SmartDataSource(
      headers: _headers,
      rows: _rows,
      onChanged: _onCellChanged,
      onRowSelected: _onRowSelected,
    );
    _computeTotals();
  }

  /// Actualiza el valor de una celda y recalcula totales.
  void _onCellChanged(int rowIndex, int colIndex, dynamic value) {
    setState(() {
      if (rowIndex >= 0 && rowIndex < _rows.length && colIndex >= 0 && colIndex < _headers.length) {
        _rows[rowIndex][colIndex] = value;
      }
      _computeTotals();
    });
  }

  /// Recibe el índice de la fila seleccionada desde la fuente de datos.
  int _selectedRow = -1;
  void _onRowSelected(int rowIndex) {
    setState(() => _selectedRow = rowIndex);
  }

  /// Calcula la suma de cada columna numérica; valores no numéricos se dejan nulos.
  void _computeTotals() {
    _totals = List<double?>.filled(_headers.length, null);
    for (int c = 0; c < _headers.length; c++) {
      final numeric = Validators.isNumericColumn(_headers[c], c);
      if (!numeric) continue;
      double total = 0.0;
      bool hasData = false;
      for (final row in _rows) {
        if (c >= row.length) continue;
        final v = row[c];
        if (v == null) continue;
        final num? parsed = num.tryParse(v.toString().replaceAll(',', '.'));
        if (parsed != null) {
          total += parsed.toDouble();
          hasData = true;
        }
      }
      _totals[c] = hasData ? total : null;
    }
  }

  /// Agrega una nueva fila utilizando sugerencias basadas en datos previos.
  void _addRow() {
    setState(() {
      final suggestion = Suggestions.suggestRow(_rows, _headers);
      _rows.add(suggestion ?? List<dynamic>.filled(_headers.length, ''));
      _dataSource.updateRows(_rows);
    });
    _computeTotals();
  }

  /// Duplica la fila seleccionada.
  void _duplicateRow() {
    if (_selectedRow < 0 || _selectedRow >= _rows.length) return;
    setState(() {
      final original = _rows[_selectedRow];
      _rows.insert(_selectedRow + 1, List<dynamic>.from(original));
      _dataSource.updateRows(_rows);
    });
    _computeTotals();
  }

  /// Elimina la fila seleccionada. Siempre queda al menos una fila vacía.
  void _removeRow() {
    if (_selectedRow < 0 || _selectedRow >= _rows.length) return;
    setState(() {
      _rows.removeAt(_selectedRow);
      if (_rows.isEmpty) {
        _rows.add(List<dynamic>.filled(_headers.length, ''));
      }
      _dataSource.updateRows(_rows);
    });
    _computeTotals();
  }

  /// Limpia todas las filas y coloca tres filas vacías.
  void _clearAll() {
    setState(() {
      _rows
        ..clear()
        ..addAll(List<List<dynamic>>.generate(3, (_) => List<dynamic>.filled(_headers.length, '')));
      _dataSource.updateRows(_rows);
    });
    _computeTotals();
  }

  /// Exporta la grilla a XLSX y ofrece compartir por email, mailto o share_plus.
  Future<void> _export() async {
    final path = await SmartExportXlsxService.instance.export(
      headers: _headers,
      rows: _rows,
      sheetName: widget.sheetName,
    );
    if (!mounted) return;
    await SmartExportXlsxService.instance.shareFile(context: context, filePath: path);
  }

  /// Construye la fila de totales en la parte inferior de la tabla.
  Widget _buildTotalsRow(GridnoteTableStyle t) {
    final cells = <Widget>[];
    // Celda índice vacía
    cells.add(Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      height: 40,
      decoration: BoxDecoration(
        color: t.headerBg,
        border: Border(
          right: BorderSide(color: t.gridLine),
          top: BorderSide(color: t.gridLine),
        ),
      ),
      child: const Text('Σ', style: TextStyle(fontWeight: FontWeight.w700)),
    ));
    for (int c = 0; c < _headers.length; c++) {
      final val = _totals[c];
      final text = val == null ? '' : val.toStringAsFixed(2);
      cells.add(Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        height: 40,
        decoration: BoxDecoration(
          color: t.headerBg,
          border: Border(
            right: BorderSide(color: t.gridLine),
            top: BorderSide(color: t.gridLine),
          ),
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      ));
    }
    return Row(children: cells);
  }

  /// Construye la barra de acciones con atajos de teclado.
  Widget _buildToolbar() {
    final t = widget.theme.theme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Agregar fila (Ctrl+N)',
            onPressed: _addRow,
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: 'Duplicar fila (Ctrl+J)',
            onPressed: _duplicateRow,
            icon: const Icon(Icons.copy),
          ),
          IconButton(
            tooltip: 'Borrar fila (Ctrl+D)',
            onPressed: _removeRow,
            icon: const Icon(Icons.delete_outline),
          ),
          IconButton(
            tooltip: 'Limpiar (Ctrl+L)',
            onPressed: _clearAll,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Exportar XLSX (Ctrl+E)',
            onPressed: _export,
            icon: const Icon(Icons.file_download),
          ),
        ],
      ),
    );
  }

  /// Define atajos de teclado para rapidez.
  Map<LogicalKeySet, Intent> get _shortcuts {
    return {
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN): const _AddRowIntent(),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyJ): const _DuplicateRowIntent(),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyD): const _DeleteRowIntent(),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyL): const _ClearAllIntent(),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyE): const _ExportIntent(),
    };
  }

  /// Define acciones asociadas a los atajos.
  Map<Type, Action<Intent>> get _actions {
    return {
      _AddRowIntent: CallbackAction<_AddRowIntent>(onInvoke: (_) {
        _addRow();
        return null;
      }),
      _DuplicateRowIntent: CallbackAction<_DuplicateRowIntent>(onInvoke: (_) {
        _duplicateRow();
        return null;
      }),
      _DeleteRowIntent: CallbackAction<_DeleteRowIntent>(onInvoke: (_) {
        _removeRow();
        return null;
      }),
      _ClearAllIntent: CallbackAction<_ClearAllIntent>(onInvoke: (_) {
        _clearAll();
        return null;
      }),
      _ExportIntent: CallbackAction<_ExportIntent>(onInvoke: (_) {
        unawaited(_export());
        return null;
      }),
    };
  }

  @override
  Widget build(BuildContext context) {
    final tableStyle = GridnoteTableStyle.from(widget.theme.theme);
    // Actualizar el estilo de la tabla en la fuente de datos para reflejar el tema actual.
    _dataSource.updateStyle(tableStyle);
    return Shortcuts(
      shortcuts: _shortcuts,
      child: Actions(
        actions: _actions,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildToolbar(),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tableStyle.cellBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: tableStyle.gridLine.withOpacity(0.8)),
                  boxShadow: [
                    if (widget.theme.theme.scaffold.computeLuminance() > 0.5)
                      const BoxShadow(
                        blurRadius: 20,
                        offset: Offset(0, 10),
                        color: Color(0x15000000),
                      ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Column(
                    children: [
                      Expanded(
                        child: SfDataGrid(
                          key: _gridKey,
                          source: _dataSource,
                          columnWidthMode: ColumnWidthMode.none,
                          allowEditing: true,
                          navigationMode: GridNavigationMode.cell,
                          selectionMode: SelectionMode.single,
                          onSelectionChanged: (added, removed) {
                            if (added.isNotEmpty) {
                              _dataSource.selectRow(added.first);
                            }
                          },
                          headerRowHeight: 42,
                          rowHeight: 38,
                          frozenColumnsCount: 1,
                          gridLinesVisibility: GridLinesVisibility.both,
                          headerGridLinesVisibility: GridLinesVisibility.both,
                          columns: _buildColumns(tableStyle),
                        ),
                      ),
                      _buildTotalsRow(tableStyle),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construye la lista de columnas incluyendo la primera columna índice.
  List<GridColumn> _buildColumns(GridnoteTableStyle t) {
    final List<GridColumn> cols = [];
    // Columna índice
    cols.add(GridColumn(
      columnName: '#',
      width: 60,
      label: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        color: t.headerBg,
        child: Text('#', style: TextStyle(color: t.headerText, fontWeight: FontWeight.w700)),
      ),
    ));
    // Columnas dinámicas
    for (int i = 0; i < _headers.length; i++) {
      final header = _headers[i].isEmpty ? 'Col ${i + 1}' : _headers[i];
      cols.add(GridColumn(
        columnName: header,
        width: 180,
        label: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          color: t.headerBg,
          child: Text(
            header,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: t.headerText, fontWeight: FontWeight.w700),
          ),
        ),
      ));
    }
    return cols;
  }
}

// ---------- Intents para atajos ----------
class _AddRowIntent extends Intent { const _AddRowIntent(); }
class _DuplicateRowIntent extends Intent { const _DuplicateRowIntent(); }
class _DeleteRowIntent extends Intent { const _DeleteRowIntent(); }
class _ClearAllIntent extends Intent { const _ClearAllIntent(); }
class _ExportIntent extends Intent { const _ExportIntent(); }