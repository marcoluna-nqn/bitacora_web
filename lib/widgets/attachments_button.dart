// Botón de Adjuntos para Web (lista/abre/elimina adjuntos por fila).
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../services/attachments_service_web.dart';

typedef RowKeyProvider = (String sheetId, int rowIndex)? Function();

class AttachmentsButton extends StatefulWidget {
  const AttachmentsButton({super.key, required this.getCurrentRow});
  final RowKeyProvider getCurrentRow;

  @override
  State<AttachmentsButton> createState() => _AttachmentsButtonState();
}

class _AttachmentsButtonState extends State<AttachmentsButton> {
  List<AttachmentRecord> _items = const [];
  (String sheetId, int rowIndex)? _row;

  Future<void> _reload() async {
    _row = widget.getCurrentRow();
    if (_row == null) return;
    final xs = await AttachmentsServiceWeb.I.listFor(
      sheetId: _row!.$1,
      row: _row!.$2,
    );
    if (!mounted) return;
    setState(() => _items = xs);
  }

  Future<void> _add() async {
    _row = widget.getCurrentRow();
    if (_row == null) return;
    await AttachmentsServiceWeb.I.pickAndAdd(
      sheetId: _row!.$1,
      row: _row!.$2,
    );
    await _reload();
  }

  Future<void> _delete(AttachmentRecord m) async {
    if (_row == null) return;
    await AttachmentsServiceWeb.I.delete(m.id);
    await _reload();
  }

  Future<void> _open(AttachmentRecord m) async {
    final ok = await launchUrlString(mapsUrl(m)); // no maps; sólo abre url data
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el archivo')),
      );
    }
  }

  String mapsUrl(AttachmentRecord m) => m.name; // placeholder no usado; usamos sheet modal

  @override
  Widget build(BuildContext context) {
    final hasItems = _items.isNotEmpty;

    return Row(
      children: [
        IconButton(
          tooltip: 'Adjuntar archivos a esta fila',
          onPressed: _add,
          icon: const Icon(Icons.attach_file),
        ),
        IconButton(
          tooltip: 'Ver adjuntos de la fila',
          onPressed: () async {
            await _reload();
            if (!mounted) return;
            showModalBottomSheet(
              context: context,
              showDragHandle: true,
              builder: (_) => _AttachmentsSheet(
                items: _items,
                onOpen: (m) async =>
                    AttachmentsServiceWeb.I.openInNewTab(m.id),
                onDelete: _delete,
                onAdd: _add,
              ),
            );
          },
          icon: Icon(hasItems ? Icons.folder_open : Icons.folder),
        ),
      ],
    );
  }
}

class _AttachmentsSheet extends StatelessWidget {
  const _AttachmentsSheet({
    required this.items,
    required this.onOpen,
    required this.onDelete,
    required this.onAdd,
  });

  final List<AttachmentRecord> items;
  final Future<void> Function(AttachmentRecord) onOpen;
  final Future<void> Function(AttachmentRecord) onDelete;
  final Future<void> Function() onAdd;

  String _fmtSize(int b) {
    const kb = 1024;
    const mb = 1024 * 1024;
    if (b >= mb) return '${(b / mb).toStringAsFixed(2)} MB';
    if (b >= kb) return '${(b / kb).toStringAsFixed(1)} KB';
    return '$b B';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.attach_file),
                const SizedBox(width: 8),
                Text('Adjuntos (${items.length})',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: items.isEmpty
                  ? const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No hay archivos adjuntos en esta fila.'),
              )
                  : ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final m = items[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.insert_drive_file),
                    title: Text(m.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${m.mime} • ${_fmtSize(m.size)}'),
                    onTap: () => onOpen(m),
                    trailing: IconButton(
                      tooltip: 'Eliminar',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => onDelete(m),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
