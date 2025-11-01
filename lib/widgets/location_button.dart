// lib/widgets/location_button.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/location_web_service.dart';
import '../services/row_geo_store.dart';

typedef RowLocator = (String sheetId, int row)? Function();

class LocationButton extends StatelessWidget {
  const LocationButton({super.key, required this.getCurrentRow});
  final RowLocator getCurrentRow;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Ubicación de la fila',
      icon: const Icon(Icons.my_location),
      onPressed: () => _openSheet(context),
    );
  }

  Future<void> _openSheet(BuildContext context) async {
    final loc = getCurrentRow();
    if (loc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccioná una fila para usar ubicación')),
      );
      return;
    }
    // ignore: use_build_context_synchronously
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _LocationSheet(sheetId: loc.$1, row: loc.$2),
    );
  }
}

class _LocationSheet extends StatefulWidget {
  const _LocationSheet({required this.sheetId, required this.row});
  final String sheetId;
  final int row;

  @override
  State<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<_LocationSheet> {
  bool _busy = false;
  String? _error;
  RowGeo? _geo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final g = await RowGeoStore.I.get(widget.sheetId, widget.row);
    if (!mounted) return;
    setState(() => _geo = g);
  }

  String _fmt(double v) => v.toStringAsFixed(6);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = 'Ubicación — Fila ${widget.row + 1}';
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16, right: 16, top: 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                tooltip: 'Borrar',
                onPressed: (_geo == null || _busy)
                    ? null
                    : () async {
                  setState(() => _busy = true);
                  await RowGeoStore.I.clear(widget.sheetId, widget.row);
                  await _load();
                  if (mounted) setState(() => _busy = false);
                },
                icon: const Icon(Icons.delete_outline),
              ),
            ]),
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            if (_error != null) Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ),
            const SizedBox(height: 8),
            if (_geo == null)
              Opacity(
                opacity: 0.8,
                child: Column(
                  children: [
                    const Icon(Icons.location_off, size: 40),
                    const SizedBox(height: 6),
                    Text('Sin ubicación guardada', style: theme.textTheme.bodyMedium),
                  ],
                ),
              )
            else
              Card(
                child: ListTile(
                  title: Text('${_fmt(_geo!.lat)}, ${_fmt(_geo!.lng)}'),
                  subtitle: Text(
                    'Precisión: ${_geo!.accuracyM?.toStringAsFixed(1) ?? '-'} m • ${_geo!.ts}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Abrir en Maps',
                    icon: const Icon(Icons.map_outlined),
                    onPressed: () async {
                      await LocationWebService.I.openInMaps(_geo!.lat, _geo!.lng);
                    },
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _onCapture,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Obtener/Actualizar'),
                  ),
                ),
                const SizedBox(width: 8),
                if (_geo != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final txt = LocationWebService.I.shareText(
                          LocationFix(lat: _geo!.lat, lng: _geo!.lng, accuracyM: _geo!.accuracyM, ts: _geo!.ts),
                        );
                        Clipboard.setData(ClipboardData(text: txt));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copiado')),
                        );
                      },
                      icon: const Icon(Icons.copy_all),
                      label: const Text('Copiar'),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _onCapture() async {
    setState(() { _busy = true; _error = null; });
    try {
      final fix = await LocationWebService.I.getCurrent();
      final g = RowGeo(
        sheetId: widget.sheetId,
        row: widget.row,
        lat: fix.lat,
        lng: fix.lng,
        accuracyM: fix.accuracyM,
        ts: fix.ts,
      );
      await RowGeoStore.I.save(g);
      await _load();
    } catch (e) {
      if (mounted) _error = '$e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
