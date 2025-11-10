// lib/screens/start_page.dart
// Inicio profesional y responsive para Bitácora Web.
// Null-safety, sin TODOs, sin usar BuildContext tras async gaps.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../workers/json_worker.dart';
import '../services/sheet_store.dart';
import '../services/export_xlsx_service.dart';
import '../widgets/glass_appbar.dart';
import 'editor_screen.dart';

class StartPage extends StatefulWidget {
  const StartPage({
    super.key,
    required this.isLight,
    required this.onToggleTheme,
  });
  final bool isLight;
  final VoidCallback onToggleTheme;

  @override
  State<StartPage> createState() => _StartPageState();
}

enum _ViewMode { list, grid }
enum _SortMode { updatedDesc, titleAsc, rowsDesc }

class _StartPageState extends State<StartPage> {
  List<SheetMeta> _items = [];
  String _q = '';
  _ViewMode _view = _ViewMode.list;
  _SortMode _sort = _SortMode.updatedDesc;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() => _items = SheetStore.list());

  Future<void> _newSheet() async {
    final id = SheetStore.createNew();
    _reload();
    if (!mounted) return;
    await Navigator.push(
      context,
      _NoAnimRoute(
        child: EditorScreen(
          isLight: widget.isLight,
          onToggleTheme: widget.onToggleTheme,
          sheetId: id,
        ),
      ),
    );
    if (!mounted) return;
    _reload();
  }

  Future<void> _rename(SheetMeta m) async {
    final t = TextEditingController(text: m.title);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renombrar planilla'),
        content: TextField(
          controller: t,
          decoration: const InputDecoration(labelText: 'Título'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, t.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (name != null) {
      SheetStore.rename(m.id, name);
      _reload();
    }
  }

  Future<void> _open(SheetMeta m) async {
    await Navigator.push(
      context,
      _NoAnimRoute(
        child: EditorScreen(
          isLight: widget.isLight,
          onToggleTheme: widget.onToggleTheme,
          sheetId: m.id,
        ),
      ),
    );
    if (!mounted) return;
    _reload();
  }

  String _fmt(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'justo ahora';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _exportSheet(SheetMeta m) async {
    final raw = SheetStore.loadRaw(m.id);
    if (raw == null) {
      _toast('No se pudo leer la planilla.');
      return;
    }
    final parsed = await JsonWorker.parseOnce(raw);
    final name = _sanitizeFileName(m.title.isEmpty ? 'bitacora' : m.title);
    await ExportXlsxService.download(
      fileName: '$name.xlsx',
      headers: parsed.headers,
      rows: parsed.rows,
    );
  }

  String _sanitizeFileName(String s) {
    final r = RegExp(r'[\\/:*?"<>|]+');
    final cleaned = s.trim().replaceAll(r, '_');
    return cleaned.isEmpty ? 'bitacora' : cleaned;
  }

  void _toast(String msg) {
    final m = ScaffoldMessenger.maybeOf(context);
    if (m == null) return;
    m.clearSnackBars();
    m.showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  // ----- Derivados para UI -----

  List<SheetMeta> get _filteredSorted {
    var list = _q.isEmpty
        ? List<SheetMeta>.from(_items)
        : _items
        .where((e) => (e.title.isEmpty ? 'Planilla' : e.title)
        .toLowerCase()
        .contains(_q.toLowerCase()))
        .toList();

    list.sort((a, b) {
      switch (_sort) {
        case _SortMode.updatedDesc:
          return b.updatedAt.compareTo(a.updatedAt);
        case _SortMode.titleAsc:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case _SortMode.rowsDesc:
          return b.rows.compareTo(a.rows);
      }
    });
    return list;
  }

  ({int total, int today, int totalRows}) get _stats {
    final now = DateTime.now();
    int total = _items.length;
    int today = 0;
    int totalRows = 0;
    for (final m in _items) {
      final d = m.updatedAt;
      if (d.year == now.year && d.month == now.month && d.day == now.day) {
        today++;
      }
      totalRows += m.rows;
    }
    return (total: total, today: today, totalRows: totalRows);
  }

  @override
  Widget build(BuildContext context) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    final data = _filteredSorted;
    final s = _stats;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Bitácora Web'),
        flexibleSpace: GlassAppBarBackground(isLight: isLightTheme),
        actions: [
          _SortMenu(
            current: _sort,
            onChanged: (v) => setState(() => _sort = v),
          ),
          IconButton(
            tooltip: _view == _ViewMode.list
                ? 'Vista de grilla'
                : 'Vista de lista',
            onPressed: () => setState(
                  () => _view =
              _view == _ViewMode.list ? _ViewMode.grid : _ViewMode.list,
            ),
            icon: Icon(_view == _ViewMode.list
                ? Icons.grid_view_rounded
                : Icons.view_list_rounded),
          ),
          IconButton(
            tooltip:
            isLightTheme ? 'Cambiar a oscuro' : 'Cambiar a claro',
            onPressed: widget.onToggleTheme,
            icon: Icon(
                isLightTheme ? Icons.dark_mode : Icons.light_mode),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newSheet,
        label: const Text('Nueva'),
        icon: const Icon(Icons.add),
      )
          .animate()
          .fadeIn(duration: 260.ms, delay: 100.ms)
          .scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: LayoutBuilder(
              builder: (context, cons) {
                final maxW = cons.maxWidth.isFinite
                    ? cons.maxWidth
                    : MediaQuery.of(context).size.width;
                final columns = maxW >= 1220
                    ? 3
                    : maxW >= 900
                    ? 2
                    : 1;

                return ListView(
                  padding:
                  const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    _HeroHeader(onNew: _newSheet)
                        .animate()
                        .fadeIn(duration: 280.ms)
                        .move(begin: const Offset(0, 12)),
                    const SizedBox(height: 12),
                    _KpiRow(
                      total: s.total,
                      today: s.today,
                      totalRows: s.totalRows,
                    )
                        .animate()
                        .fadeIn(duration: 260.ms, delay: 40.ms)
                        .move(begin: const Offset(0, 10)),
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (v) => setState(() => _q = v),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Buscar planilla…',
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 240.ms, delay: 70.ms)
                        .move(begin: const Offset(0, 8)),
                    const SizedBox(height: 12),
                    if (data.isEmpty)
                      _EmptyState(onNew: _newSheet)
                          .animate()
                          .fadeIn(
                          duration: 240.ms, delay: 100.ms)
                    else
                      (_view == _ViewMode.list)
                          ? Column(
                        children: [
                          for (int i = 0; i < data.length; i++)
                            _SheetListTile(
                              meta: data[i],
                              fmt: _fmt,
                              onOpen: _open,
                              onExport: _exportSheet,
                              onRename: _rename,
                              onDelete: (m) {
                                SheetStore.delete(m.id);
                                _reload();
                              },
                            )
                                .animate(
                                delay:
                                (80 + i * 30).ms)
                                .fadeIn(duration: 220.ms)
                                .move(
                                begin:
                                const Offset(0, 8),
                                curve: Curves.easeOut),
                        ],
                      )
                          : _SheetGrid(
                        columns: columns,
                        items: data,
                        fmt: _fmt,
                        onOpen: _open,
                        onExport: _exportSheet,
                        onRename: _rename,
                        onDelete: (m) {
                          SheetStore.delete(m.id);
                          _reload();
                        },
                      )
                          .animate()
                          .fadeIn(
                          duration: 220.ms, delay: 80.ms),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- Widgets de pantalla ----------

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.onNew});
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = t.colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.cardColor.withOpacity(0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.dividerColor.withOpacity(0.8)),
        boxShadow: [
          if (t.brightness == Brightness.light)
            const BoxShadow(
              blurRadius: 20,
              offset: Offset(0, 10),
              color: Color(0x15000000),
            ),
        ],
      ),
      child: LayoutBuilder(
        builder: (_, cons) {
          final stacked = cons.maxWidth < 680;
          final title = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.grid_view_rounded, color: c.primary),
              const SizedBox(width: 8),
              Text(
                'Tus planillas, en un solo lugar',
                style: t.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          );

          final button = FilledButton.icon(
            onPressed: onNew,
            icon: const Icon(Icons.add),
            label: const Text('Nueva planilla'),
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: 10),
                button,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: title),
              button,
            ],
          );
        },
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({
    required this.total,
    required this.today,
    required this.totalRows,
  });
  final int total;
  final int today;
  final int totalRows;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = t.colorScheme;

    Widget kpi(String title, String value, IconData icon) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.outlineVariant),
        boxShadow: kElevationToShadow[1],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.primary.withOpacity(.12),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: c.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.textTheme.labelMedium),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: t.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (_, cons) {
        final w = cons.maxWidth;
        final cols = w >= 1100 ? 3 : w >= 720 ? 3 : 1;
        final children = [
          kpi('Total planillas', '$total', Icons.folder_open_rounded),
          kpi('Actualizadas hoy', '$today', Icons.bolt_rounded),
          kpi('Filas totales', '$totalRows', Icons.table_rows_rounded),
        ];
        if (cols == 1) {
          return Column(
            children: [
              for (int i = 0; i < children.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                      bottom: i == children.length - 1 ? 0 : 10),
                  child: children[i],
                ),
            ],
          );
        }
        return GridView.count(
          shrinkWrap: true,
          crossAxisCount: cols,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.7,
          children: children,
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onNew});
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.5),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_rounded, size: 42),
          const SizedBox(height: 10),
          Text(
            'No hay planillas',
            style: t.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text('Crea tu primera planilla para empezar.'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onNew,
            icon: const Icon(Icons.add),
            label: const Text('Nueva planilla'),
          ),
        ],
      ),
    );
  }
}

class _SheetListTile extends StatelessWidget {
  const _SheetListTile({
    required this.meta,
    required this.fmt,
    required this.onOpen,
    required this.onExport,
    required this.onRename,
    required this.onDelete,
  });
  final SheetMeta meta;
  final String Function(DateTime) fmt;
  final Future<void> Function(SheetMeta) onOpen;
  final Future<void> Function(SheetMeta) onExport;
  final Future<void> Function(SheetMeta) onRename;
  final void Function(SheetMeta) onDelete;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onOpen(meta),
        child: Padding(
          padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.description_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meta.title.isEmpty
                          ? 'Planilla sin título'
                          : meta.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${meta.rows} filas · ${fmt(meta.updatedAt)}',
                      style: t.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Exportar XLSX',
                onPressed: () => onExport(meta),
                icon: const Icon(Icons.table_view),
              ),
              IconButton(
                tooltip: 'Renombrar',
                onPressed: () => onRename(meta),
                icon: const Icon(Icons.edit_note),
              ),
              IconButton(
                tooltip: 'Abrir',
                onPressed: () => onOpen(meta),
                icon: const Icon(Icons.arrow_forward),
              ),
              _DeleteSwipe(meta: meta, onDelete: onDelete),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeleteSwipe extends StatelessWidget {
  const _DeleteSwipe({required this.meta, required this.onDelete});
  final SheetMeta meta;
  final void Function(SheetMeta) onDelete;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Eliminar',
      onPressed: () async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Eliminar'),
            content: const Text(
              '¿Eliminar esta planilla? Esta acción no se puede deshacer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        );
        if (ok == true) onDelete(meta);
      },
      icon: const Icon(Icons.delete_outline),
    );
  }
}

class _SheetGrid extends StatelessWidget {
  const _SheetGrid({
    required this.columns,
    required this.items,
    required this.fmt,
    required this.onOpen,
    required this.onExport,
    required this.onRename,
    required this.onDelete,
  });

  final int columns;
  final List<SheetMeta> items;
  final String Function(DateTime) fmt;
  final Future<void> Function(SheetMeta) onOpen;
  final Future<void> Function(SheetMeta) onExport;
  final Future<void> Function(SheetMeta) onRename;
  final void Function(SheetMeta) onDelete;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = t.colorScheme;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.3,
      ),
      itemBuilder: (_, i) {
        final m = items[i];
        return Container(
          decoration: BoxDecoration(
            color: c.surfaceContainerHighest,
            border: Border.all(color: c.outlineVariant),
            borderRadius: BorderRadius.circular(14),
            boxShadow: kElevationToShadow[1],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                m.title.isEmpty ? 'Planilla sin título' : m.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text('${m.rows} filas · ${fmt(m.updatedAt)}',
                  style: t.textTheme.bodySmall),
              const Spacer(),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => onOpen(m),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Abrir'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Exportar XLSX',
                    onPressed: () => onExport(m),
                    icon: const Icon(Icons.table_view),
                  ),
                  IconButton(
                    tooltip: 'Renombrar',
                    onPressed: () => onRename(m),
                    icon: const Icon(Icons.edit_note),
                  ),
                  const Spacer(),
                  _DeleteSwipe(meta: m, onDelete: onDelete),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------- Menú y utilidades ----------

class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.current, required this.onChanged});
  final _SortMode current;
  final ValueChanged<_SortMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_SortMode>(
      tooltip: 'Ordenar',
      initialValue: current,
      onSelected: onChanged,
      itemBuilder: (_) => const [
        PopupMenuItem(
            value: _SortMode.updatedDesc, child: Text('Recientes')),
        PopupMenuItem(
            value: _SortMode.titleAsc, child: Text('Título (A–Z)')),
        PopupMenuItem(
            value: _SortMode.rowsDesc, child: Text('Más filas')),
      ],
      icon: const Icon(Icons.sort_rounded),
    );
  }
}

class _NoAnimRoute extends PageRouteBuilder {
  _NoAnimRoute({required Widget child})
      : super(
    pageBuilder: (_, __, ___) => child,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );
}
