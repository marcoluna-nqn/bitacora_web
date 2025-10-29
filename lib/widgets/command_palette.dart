// lib/widgets/command_palette.dart
import 'package:flutter/material.dart';

class CommandAction {
  final String id;
  final String label;
  final String? subtitle;
  final String? shortcut; // Ej: "Ctrl+N"
  final IconData? icon;
  final VoidCallback onSelected;

  CommandAction({
    required this.id,
    required this.label,
    required this.onSelected,
    this.subtitle,
    this.shortcut,
    this.icon,
  });
}

/// Abre el command palette. Filtra por texto, selecciona con ↑/↓ y Enter, cierra con Esc.
/// Llamá a esto desde AppBar o atajo global (Ctrl+K / Ctrl+/).
Future<void> showCommandPalette(
    BuildContext context, {
      required List<CommandAction> actions,
      String title = 'Acciones',
    }) async {
  final queryCtl = TextEditingController();
  final focusNode = FocusNode();
  int selected = 0;

  List<CommandAction> filter(String q) {
    if (q.isEmpty) return actions;
    final s = q.toLowerCase();
    return actions.where((a) {
      final t = a.label.toLowerCase();
      final st = a.subtitle?.toLowerCase() ?? '';
      return t.contains(s) || st.contains(s);
    }).toList(growable: false);
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      List<CommandAction> results = filter('');
      final listCtl = ScrollController();

      void runSelected() {
        if (results.isEmpty) return;
        final action = results[selected.clamp(0, results.length - 1)];
        Navigator.of(ctx).pop();
        // Ejecutar después del pop.
        Future.microtask(action.onSelected);
      }

      void move(int delta) {
        if (results.isEmpty) return;
        selected = (selected + delta).clamp(0, results.length - 1);
        // Asegurar visibilidad del ítem seleccionado.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!listCtl.hasClients) return;
          final itemH = 56.0;
          final target = selected * itemH;
          final viewTop = listCtl.offset;
          final viewBot = viewTop + listCtl.position.viewportDimension;
          if (target < viewTop) {
            listCtl.jumpTo(target);
          } else if (target + itemH > viewBot) {
            listCtl.jumpTo((target + itemH) - listCtl.position.viewportDimension);
          }
        });
      }

      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: RawKeyboardListener(
          focusNode: FocusNode()..requestFocus(),
          onKey: (e) {
            // Solo KeyDown.
            if (!e.runtimeType.toString().contains('RawKeyDownEvent')) return;
            final key = e.logicalKey.keyLabel.toLowerCase();
            // Mover selección y ejecutar.
            if (e.logicalKey.keyLabel == 'Arrow Up') {
              move(-1);
            } else if (e.logicalKey.keyLabel == 'Arrow Down') {
              move(1);
            } else if (e.logicalKey.keyLabel == 'Enter') {
              runSelected();
            } else if (e.logicalKey.keyLabel == 'Escape') {
              Navigator.of(ctx).pop();
            } else {
              // Nada.
            }
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 480),
            child: Material(
              color: Theme.of(ctx).cardColor,
              borderRadius: BorderRadius.circular(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header de búsqueda
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(title,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            ),
                            const SizedBox(width: 8),
                            _Kbd('Esc'),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: queryCtl,
                          focusNode: focusNode,
                          autofocus: true,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Escribe para filtrar…',
                          ),
                          onChanged: (q) {
                            results = filter(q);
                            selected = 0;
                            // Fuerza rebuild del diálogo.
                            (ctx as Element).markNeedsBuild();
                          },
                          onSubmitted: (_) => runSelected(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 0),
                  // Lista de resultados
                  Flexible(
                    child: results.isEmpty
                        ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text('Sin resultados',
                            style: Theme.of(ctx).textTheme.bodyMedium),
                      ),
                    )
                        : ListView.builder(
                      controller: listCtl,
                      itemExtent: 56,
                      itemCount: results.length,
                      itemBuilder: (c, i) {
                        final a = results[i];
                        final sel = i == selected;
                        return InkWell(
                          onTap: () {
                            selected = i;
                            runSelected();
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: sel
                                  ? Theme.of(ctx).colorScheme.primary.withOpacity(0.08)
                                  : Colors.transparent,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Icon(a.icon ?? Icons.bolt_outlined,
                                    size: 20,
                                    color: sel
                                        ? Theme.of(ctx).colorScheme.primary
                                        : Theme.of(ctx).iconTheme.color),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(a.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w600)),
                                      if (a.subtitle != null && a.subtitle!.isNotEmpty)
                                        Text(a.subtitle!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(ctx).textTheme.bodySmall),
                                    ],
                                  ),
                                ),
                                if (a.shortcut != null)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: _Kbd(a.shortcut!),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  queryCtl.dispose();
  focusNode.dispose();
}

class _Kbd extends StatelessWidget {
  const _Kbd(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Theme.of(context).dividerColor),
        color: Theme.of(context).brightness == Brightness.light
            ? const Color(0xFFF7F7F9)
            : const Color(0xFF141922),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
