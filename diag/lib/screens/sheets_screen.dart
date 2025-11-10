import 'package:flutter/material.dart';
import '../services/sheet_store.dart';
import 'editor_screen.dart';

class SheetsScreen extends StatefulWidget {
  const SheetsScreen(
      {super.key, required this.isLight, required this.onToggleTheme});
  final bool isLight;
  final VoidCallback onToggleTheme;

  @override
  State<SheetsScreen> createState() => _SheetsScreenState();
}

class _SheetsScreenState extends State<SheetsScreen> {
  List<SheetMeta> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _items = SheetStore.list();
      _loading = false;
    });
  }

  Future<void> _open(String id) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EditorScreen(
            isLight: widget.isLight,
            onToggleTheme: widget.onToggleTheme,
            sheetId: id,
          ),
        ));
    _load();
  }

  Future<void> _newBlank() async {
    final id = SheetStore.createNew();
    if (!mounted) return;
    await _open(id);
  }

  Future<void> _newFromTemplate(TemplateKind kind) async {
    final id = SheetStore.createFromTemplate(kind);
    if (!mounted) return;
    await _open(id);
  }

  void _showTemplates() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.table_rows),
            title: const Text('Relevamiento resistividades'),
            subtitle: const Text('Fecha, Progresiva, 1m, 3m, 5m, Obs.'),
            onTap: () {
              Navigator.pop(context);
              _newFromTemplate(TemplateKind.resistividades);
            },
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('Inventario simple'),
            subtitle: const Text('Item, Cant., Unidad, Ubicación, Nota'),
            onTap: () {
              Navigator.pop(context);
              _newFromTemplate(TemplateKind.inventario);
            },
          ),
          ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: const Text('Checklist diario'),
            subtitle:
                const Text('Tarea, Responsable, Estado, Hora, Comentario'),
            onTap: () {
              Navigator.pop(context);
              _newFromTemplate(TemplateKind.checklist);
            },
          ),
        ]),
      ),
    );
  }

  void _delete(String id) {
    SheetStore.delete(id);
    _load();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Planilla eliminada'),
          duration: Duration(milliseconds: 1200)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bitácora Web'),
        actions: [
          IconButton(
            tooltip: widget.isLight ? 'Cambiar a oscuro' : 'Cambiar a claro',
            onPressed: widget.onToggleTheme,
            icon: Icon(widget.isLight ? Icons.dark_mode : Icons.light_mode),
          ),
          IconButton(
              tooltip: 'Plantillas',
              onPressed: _showTemplates,
              icon: const Icon(Icons.view_quilt_outlined)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.6))
          : _items.isEmpty
              ? _Empty(onNew: _newBlank, onTemplates: _showTemplates)
              : ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final it = _items[i];
                    return ListTile(
                      leading: const Icon(Icons.table_chart),
                      title: Text(it.title ?? 'Planilla ${it.id}'),
                      subtitle: Text('Actualizada: ${it.updatedAt.toLocal()}'),
                      onTap: () => _open(it.id),
                      trailing: IconButton(
                        tooltip: 'Eliminar',
                        onPressed: () => _delete(it.id),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newBlank,
        label: const Text('Nueva hoja'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onNew, required this.onTemplates});
  final VoidCallback onNew;
  final VoidCallback onTemplates;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.table_chart_outlined, size: 56),
        const SizedBox(height: 10),
        const Text('No hay planillas aún'),
        const SizedBox(height: 16),
        Wrap(spacing: 12, children: [
          FilledButton.icon(
              onPressed: onNew,
              icon: const Icon(Icons.add),
              label: const Text('Nueva')),
          OutlinedButton.icon(
              onPressed: onTemplates,
              icon: const Icon(Icons.view_quilt_outlined),
              label: const Text('Plantillas')),
        ]),
      ]),
    );
  }
}
