import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:bitacora_web/theme/gridnote_theme.dart';
import 'validators.dart';

typedef CellChanged = void Function(int rowIndex, int colIndex, dynamic value);
typedef RowSelected = void Function(int rowIndex);

class SmartDataSource extends DataGridSource {
  SmartDataSource({
    required List<String> headers,
    required List<List<dynamic>> rows,
    required this.onChanged,
    required this.onRowSelected,
  })  : _headers = headers,
        _rows = rows {
    _rebuild();
  }

  List<String> _headers;
  List<List<dynamic>> _rows;
  final CellChanged onChanged;
  final RowSelected onRowSelected;

  GridnoteTableStyle? _style;
  void updateStyle(GridnoteTableStyle s) {
    _style = s;
    notifyListeners();
  }

  void updateRows(List<List<dynamic>> rows) {
    _rows = rows;
    _rebuild();
    notifyListeners();
  }

  void selectRow(DataGridRow row) {
    final idx = _rowIndex(row);
    if (idx >= 0) onRowSelected(idx);
  }

  final Map<String, TextEditingController> _ctls = {};
  String _k(int r, int c) => '$r:$c';

  late List<DataGridRow> _dgRows;
  @override
  List<DataGridRow> get rows => _dgRows;

  void _rebuild() {
    _dgRows = List<DataGridRow>.generate(_rows.length, (r) {
      return DataGridRow(cells: <DataGridCell>[
        DataGridCell<int>(columnName: '#', value: r + 1),
        ...List<DataGridCell<dynamic>>.generate(_headers.length, (c) {
          final v = c < _rows[r].length ? _rows[r][c] : '';
          return DataGridCell<dynamic>(columnName: 'c$c', value: v);
        }),
      ]);
    });
  }

  int _rowIndex(DataGridRow row) {
    final cell = row.getCells().firstWhere((e) => e.columnName == '#', orElse: () => const DataGridCell(columnName: '#', value: 0));
    final v = (cell.value ?? 0) as int;
    return v - 1;
  }

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final t = _style;
    final r = _rowIndex(row);

    final cells = <Widget>[
      _indexCell(r, t),
      for (int c = 0; c < _headers.length; c++) _editCell(r, c, t),
    ];
    return DataGridRowAdapter(cells: cells);
  }

  Widget _indexCell(int r, GridnoteTableStyle? t) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text('${r + 1}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
    );
  }

  Widget _editCell(int r, int c, GridnoteTableStyle? t) {
    final key = _k(r, c);
    final initial = (c < _rows[r].length ? _rows[r][c] : '').toString();
    final ctl = _ctls.putIfAbsent(key, () => TextEditingController(text: initial));
    if (ctl.text != initial) ctl.text = initial;

    final numeric = Validators.isNumericColumn(_headers[c], c);
    final inputFmt = numeric
        ? <TextInputFormatter>[FilteringTextInputFormatter.allow(RegExp(r'[0-9.,-]'))]
        : const <TextInputFormatter>[];

    return Container(
      alignment: numeric ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TextField(
        controller: ctl,
        maxLines: 1,
        textAlign: numeric ? TextAlign.right : TextAlign.left,
        keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true, signed: true) : TextInputType.text,
        inputFormatters: inputFmt,
        decoration: const InputDecoration(isDense: true, border: InputBorder.none),
        style: const TextStyle(fontSize: 13.5),
        onChanged: (v) => onChanged(r, c, v),
      ),
    );
  }
}
