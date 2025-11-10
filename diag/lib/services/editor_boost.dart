// lib/services/editor_boost.dart
// EditorBoost: hotkeys de edición + ajuste automático de columnas al viewport (responsive).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Callbacks mínimos que el Editor expone al booster.
class EditorBindings {
  EditorBindings({
    required this.rowCount,
    required this.colCount,
    required this.getFocus, // retorna (r,c) actual
    required this.setFocus, // mover foco a (r,c)
    required this.startEdit, // activar edición en (r,c)
    required this.writeCell, // escribir valor directo (sin requerir modo edición)
    required this.readCell, // leer valor de (r,c)
    required this.newRow, // insertar nueva fila al final
    required this.deleteRow, // borrar fila actual
    required this.undo,
    required this.redo,
    required this.autoFitColumn, // autofit de una columna
    required this.clearCell, // limpiar celda actual
  });

  final int Function() rowCount;
  final int Function() colCount;
  final ({int r, int c}) Function() getFocus;
  final void Function(int r, int c) setFocus;
  final void Function(int r, int c) startEdit;
  final void Function(int r, int c, String value) writeCell;
  final String Function(int r, int c) readCell;
  final VoidCallback newRow;
  final VoidCallback deleteRow;
  final VoidCallback undo;
  final VoidCallback redo;
  final void Function(int colIndex) autoFitColumn;
  final void Function(int r, int c) clearCell;
}

/// Widget que inyecta atajos sin romper los que ya tenés.
class EditorBoost extends StatelessWidget {
  const EditorBoost({super.key, required this.bindings, required this.child});
  final EditorBindings bindings;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mapShortcuts = <LogicalKeySet, Intent>{
      // Edición rápida
      LogicalKeySet(LogicalKeyboardKey.f2): const _EditIntent(),
      LogicalKeySet(LogicalKeyboardKey.delete): const _ClearIntent(),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.enter):
          const _NewRowBelowIntent(),

      // Clipboard
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyC):
          const _CopyIntent(),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyX):
          const _CutIntent(),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyV):
          const _PasteIntent(),

      // Navegación extendida
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.arrowLeft):
          const _MoveStartColIntent(),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.arrowRight):
          const _MoveEndColIntent(),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.arrowUp):
          const _MoveStartRowIntent(),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.arrowDown):
          const _MoveEndRowIntent(),
      LogicalKeySet(LogicalKeyboardKey.pageUp): const _PageUpIntent(),
      LogicalKeySet(LogicalKeyboardKey.pageDown): const _PageDownIntent(),

      // Utilidades
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyF):
          const _AutoFitIntent(), // Ctrl+F: autofit col
    };

    final mapActions = <Type, Action<Intent>>{
      _EditIntent: CallbackAction<_EditIntent>(onInvoke: (_) {
        final f = bindings.getFocus();
        bindings.startEdit(f.r, f.c);
        return null;
      }),
      _ClearIntent: CallbackAction<_ClearIntent>(onInvoke: (_) {
        final f = bindings.getFocus();
        bindings.clearCell(f.r, f.c);
        return null;
      }),
      _NewRowBelowIntent: CallbackAction<_NewRowBelowIntent>(onInvoke: (_) {
        final f = bindings.getFocus();
        bindings.newRow();
        final r = (f.r + 1).clamp(0, bindings.rowCount() - 1);
        bindings.setFocus(r, f.c);
        return null;
      }),

      // Clipboard
      _CopyIntent: CallbackAction<_CopyIntent>(onInvoke: (_) {
        final f = bindings.getFocus();
        final txt = bindings.readCell(f.r, f.c);
        Clipboard.setData(ClipboardData(text: txt));
        return null;
      }),
      _CutIntent: CallbackAction<_CutIntent>(onInvoke: (_) {
        final f = bindings.getFocus();
        final txt = bindings.readCell(f.r, f.c);
        Clipboard.setData(ClipboardData(text: txt));
        bindings.writeCell(f.r, f.c, '');
        return null;
      }),
      _PasteIntent: CallbackAction<_PasteIntent>(onInvoke: (_) async {
        final f = bindings.getFocus();
        final data = await Clipboard.getData('text/plain');
        final txt = (data?.text ?? '').replaceAll('\r\n', '\n');
        // Si viene una sola celda, pegamos directo
        if (!txt.contains('\n') && !txt.contains('\t')) {
          bindings.writeCell(f.r, f.c, txt);
          return null;
        }
        // Soporte básico multi-celda: distribuye por filas/columnas
        final rows = txt.split('\n').map((l) => l.split('\t')).toList();
        int rr = f.r;
        for (final line in rows) {
          int cc = f.c;
          for (final cell in line) {
            if (rr < bindings.rowCount() && cc < bindings.colCount()) {
              bindings.writeCell(rr, cc, cell);
            }
            cc++;
          }
          rr++;
        }
        return null;
      }),

      // Navegación extendida
      _MoveStartColIntent: CallbackAction<_MoveStartColIntent>(onInvoke: (_) {
        final f = bindings.getFocus();
        bindings.setFocus(f.r, 0);
        return null;
      }),
      _MoveEndColIntent: CallbackAction<_MoveEndColIntent>(onInvoke: (_) {
        final f = bindings.getFocus();
        bindings.setFocus(f.r, bindings.colCount() - 1);
        return null;
      }),
      _MoveStartRowIntent: CallbackAction<_MoveStartRowIntent>(onInvoke: (_) {
        final f = bindings.getFocus();
        bindings.setFocus(0, f.c);
        return null;
      }),
      _MoveEndRowIntent: CallbackAction<_MoveEndRowIntent>(onInvoke: (_) {
        final f = bindings.getFocus();
        bindings.setFocus(bindings.rowCount() - 1, f.c);
        return null;
      }),
      _PageUpIntent: CallbackAction<_PageUpIntent>(onInvoke: (_) {
        final f = bindings.getFocus();
        final r = (f.r - 10).clamp(0, bindings.rowCount() - 1);
        bindings.setFocus(r, f.c);
        return null;
      }),
      _PageDownIntent: CallbackAction<_PageDownIntent>(onInvoke: (_) {
        final f = bindings.getFocus();
        final r = (f.r + 10).clamp(0, bindings.rowCount() - 1);
        bindings.setFocus(r, f.c);
        return null;
      }),

      _AutoFitIntent: CallbackAction<_AutoFitIntent>(onInvoke: (_) {
        final f = bindings.getFocus();
        bindings.autoFitColumn(f.c);
        return null;
      }),
    };

    return Shortcuts(
      shortcuts: mapShortcuts,
      child: Actions(
          actions: mapActions, child: FocusTraversalGroup(child: child)),
    );
  }
}

/// Distribuye ancho extra para que las columnas llenen el viewport.
/// Retorna una nueva lista con los anchos ajustados.
List<double> fitColumnsToViewport({
  required List<double> widths,
  required double viewportWidth,
  required double indexColumnWidth,
  required double minColWidth,
  required double maxColWidth,
}) {
  final usable = (viewportWidth - indexColumnWidth).clamp(0, double.infinity);
  final sum = widths.fold<double>(0, (a, b) => a + b);
  if (sum >= usable) return widths;

  final extra = usable - sum;
  final per = extra / widths.length;
  return [
    for (final w in widths)
      (w + per).clamp(minColWidth, maxColWidth).toDouble(),
  ];
}

/// Widget que llama a `onWidths` cuando el viewport cambia, para estirar columnas.
class ViewportFiller extends StatefulWidget {
  const ViewportFiller({
    super.key,
    required this.indexColumnWidth,
    required this.minColWidth,
    required this.maxColWidth,
    required this.getWidths,
    required this.onWidths,
    required this.child,
  });

  final double indexColumnWidth;
  final double minColWidth;
  final double maxColWidth;
  final List<double> Function() getWidths;
  final void Function(List<double> next) onWidths;
  final Widget child;

  @override
  State<ViewportFiller> createState() => _ViewportFillerState();
}

class _ViewportFillerState extends State<ViewportFiller> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, box) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final current = widget.getWidths();
          final next = fitColumnsToViewport(
            widths: current,
            viewportWidth: box.maxWidth,
            indexColumnWidth: widget.indexColumnWidth,
            minColWidth: widget.minColWidth,
            maxColWidth: widget.maxColWidth,
          );
          // Solo actualizamos si realmente cambia
          bool changed = false;
          if (next.length == current.length) {
            for (int i = 0; i < next.length; i++) {
              if ((next[i] - current[i]).abs() > 0.5) {
                changed = true;
                break;
              }
            }
          } else {
            changed = true;
          }
          if (changed && mounted) {
            widget.onWidths(next);
          }
        });
        return widget.child;
      },
    );
  }
}

// ---- Intents internos ----
class _EditIntent extends Intent {
  const _EditIntent();
}

class _ClearIntent extends Intent {
  const _ClearIntent();
}

class _CopyIntent extends Intent {
  const _CopyIntent();
}

class _CutIntent extends Intent {
  const _CutIntent();
}

class _PasteIntent extends Intent {
  const _PasteIntent();
}

class _MoveStartColIntent extends Intent {
  const _MoveStartColIntent();
}

class _MoveEndColIntent extends Intent {
  const _MoveEndColIntent();
}

class _MoveStartRowIntent extends Intent {
  const _MoveStartRowIntent();
}

class _MoveEndRowIntent extends Intent {
  const _MoveEndRowIntent();
}

class _PageUpIntent extends Intent {
  const _PageUpIntent();
}

class _PageDownIntent extends Intent {
  const _PageDownIntent();
}

class _NewRowBelowIntent extends Intent {
  const _NewRowBelowIntent();
}

class _AutoFitIntent extends Intent {
  const _AutoFitIntent();
}
