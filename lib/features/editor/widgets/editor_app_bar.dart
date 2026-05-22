part of '../editor_screen.dart';

class _PremiumAppleHeader extends StatelessWidget {
  const _PremiumAppleHeader({
    required this.palette,
    required this.titleController,
    required this.titleFocus,
    required this.controller,
    required this.onTitleChanged,
    required this.onToggleTheme,
    required this.onUndo,
    required this.onRedo,
    required this.onAddRow,
    required this.onQuickCapture,
    required this.onForm,
    required this.onSearch,
    required this.onSearchEverywhere,
    required this.onJumpTo,
    required this.onColumns,
    required this.onHistory,
    required this.onSaveView,
    required this.onSelectView,
    required this.onManageViews,
    required this.onMarkReviewed,
    required this.onTogglePendingReviewView,
    required this.onSave,
    required this.onExport,
    required this.onSmokeTest,
    required this.onCompute,
    required this.onBatch,
    required this.onGps,
    required this.onPhoto,
    required this.onVideo,
    required this.onAudio,
    required this.onFile,
    required this.onAttachments,
    required this.onShare,
    required this.onCollaborate,
    required this.onPalette,
    required this.onGpsMode,
    required this.onDensity,
    required this.onOpenOfflineQueue,
    required this.lastLocalSavedAt,
    required this.sensorsEnabled,
    required this.selectedRow,
    required this.selectedCol,
    required this.selectedRowsCount,
    required this.pendingOfflineCount,
    required this.outboxPendingCount,
    required this.outboxErrorCount,
    required this.errorsCount,
    required this.savedViews,
    required this.activeViewId,
    required this.pendingReviewViewActive,
  });

  final _SheetPalette palette;
  final bool sensorsEnabled;

  final TextEditingController titleController;
  final FocusNode titleFocus;
  final EditorController controller;

  final ValueChanged<String> onTitleChanged;

  final VoidCallback onToggleTheme;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onAddRow;
  final VoidCallback onQuickCapture;
  final VoidCallback onForm;
  final VoidCallback onSearch;
  final VoidCallback onSearchEverywhere;
  final VoidCallback onJumpTo;
  final VoidCallback onColumns;
  final VoidCallback onHistory;
  final VoidCallback onSaveView;
  final ValueChanged<String?> onSelectView;
  final VoidCallback onManageViews;
  final VoidCallback onMarkReviewed;
  final VoidCallback onTogglePendingReviewView;

  final VoidCallback onSave;
  final VoidCallback onExport;
  final VoidCallback onSmokeTest;
  final VoidCallback? onCompute;
  final VoidCallback onBatch;

  final VoidCallback onGps;
  final VoidCallback onPhoto;
  final VoidCallback onVideo;
  final VoidCallback onAudio;
  final VoidCallback onFile;
  final VoidCallback onAttachments;
  final VoidCallback onShare;
  final VoidCallback onCollaborate;
  final VoidCallback onPalette;
  final VoidCallback onGpsMode;
  final VoidCallback onDensity;
  final VoidCallback onOpenOfflineQueue;
  final DateTime? lastLocalSavedAt;
  final int selectedRow;
  final int selectedCol;
  final int selectedRowsCount;
  final int pendingOfflineCount;
  final int outboxPendingCount;
  final int outboxErrorCount;
  final int errorsCount;
  final List<_SavedView> savedViews;
  final String? activeViewId;
  final bool pendingReviewViewActive;

  String _formatLocalSaved(DateTime? value) {
    if (value == null) return 'Local --:--';
    final local = value.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return 'Local $hh:$mm';
  }

  static String _columnLabel(int col) {
    var value = col + 1;
    final out = StringBuffer();
    while (value > 0) {
      final rem = (value - 1) % 26;
      out.writeCharCode(65 + rem);
      value = (value - 1) ~/ 26;
    }
    return out.toString().split('').reversed.join();
  }

  String _selectionLabel() {
    if (selectedRow < 0 || selectedCol < 0) return 'Sin selecci\u00f3n';
    return 'Celda ${_columnLabel(selectedCol)}${selectedRow + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final top = math.max(6.0, pad.top);

    final evidenceItems = <AppleToolbarItem>[
      AppleToolbarItem(
        icon: Icons.photo_camera_outlined,
        label: 'C\u00e1mara',
        shortcut: 'P',
        onTap: onPhoto,
        enabled: sensorsEnabled,
        onDisabledTap: onPhoto,
      ),
      AppleToolbarItem(
        icon: Icons.videocam_outlined,
        label: 'Video',
        onTap: onVideo,
      ),
      AppleToolbarItem(
        icon: Icons.mic_none_rounded,
        label: 'Audio',
        shortcut: 'A',
        onTap: onAudio,
        enabled: sensorsEnabled,
        onDisabledTap: onAudio,
      ),
      AppleToolbarItem(
        icon: Icons.my_location_rounded,
        label: 'GPS',
        shortcut: 'G',
        onTap: onGps,
        enabled: sensorsEnabled,
        onDisabledTap: onGps,
      ),
      AppleToolbarItem(
        icon: Icons.tune_rounded,
        label: 'Modo GPS',
        onTap: onGpsMode,
      ),
      AppleToolbarItem(
        icon: Icons.attach_file_rounded,
        label: 'Adjuntos',
        onTap: onAttachments,
      ),
      AppleToolbarItem(
        icon: Icons.upload_file_outlined,
        label: 'Archivo',
        onTap: onFile,
      ),
    ];

    final reviewItems = <AppleToolbarItem>[
      AppleToolbarItem(
        icon: Icons.verified_rounded,
        label: 'Marcar revisado',
        onTap: onMarkReviewed,
      ),
      AppleToolbarItem(
        icon: pendingReviewViewActive
            ? Icons.pending_actions_rounded
            : Icons.fact_check_outlined,
        label: pendingReviewViewActive ? 'Pendientes' : 'Ver pendientes',
        onTap: onTogglePendingReviewView,
      ),
      AppleToolbarItem(
        icon: Icons.history_rounded,
        label: 'Historial',
        onTap: onHistory,
      ),
      AppleToolbarItem(
        icon: Icons.group_work_outlined,
        label: 'Colaborar',
        onTap: onCollaborate,
      ),
    ];

    final moreItems = <AppleToolbarItem>[
      AppleToolbarItem(
        icon: palette.isLight
            ? Icons.dark_mode_outlined
            : Icons.light_mode_outlined,
        label: palette.isLight ? 'Modo oscuro' : 'Modo claro',
        onTap: onToggleTheme,
      ),
      AppleToolbarItem(
        icon: Icons.undo_rounded,
        label: 'Deshacer',
        onTap: onUndo,
      ),
      AppleToolbarItem(
        icon: Icons.redo_rounded,
        label: 'Rehacer',
        onTap: onRedo,
      ),
      AppleToolbarItem(
        icon: Icons.add_rounded,
        label: 'Nueva fila',
        onTap: onAddRow,
      ),
      AppleToolbarItem(
        icon: Icons.description_outlined,
        label: 'Formulario',
        onTap: onForm,
      ),
      AppleToolbarItem(
        icon: Icons.layers_outlined,
        label: AppStrings.editorBatchActions,
        onTap: onBatch,
      ),
      AppleToolbarItem(
        icon: Icons.pin_drop_outlined,
        label: 'Ir a...',
        shortcut: 'Ctrl/Cmd+J',
        onTap: onJumpTo,
      ),
      AppleToolbarItem(
        icon: Icons.travel_explore_rounded,
        label: 'Buscar global',
        shortcut: 'Ctrl/Cmd+Shift+F',
        onTap: onSearchEverywhere,
      ),
      AppleToolbarItem(
        icon: Icons.table_view_rounded,
        label: 'Vista base',
        onTap: () => onSelectView(null),
      ),
      for (final view in savedViews.take(6))
        AppleToolbarItem(
          icon: view.id == activeViewId
              ? Icons.visibility_rounded
              : Icons.visibility_outlined,
          label: view.name,
          onTap: () => onSelectView(view.id),
        ),
      AppleToolbarItem(
        icon: Icons.bookmark_add_outlined,
        label: 'Guardar vista',
        onTap: onSaveView,
      ),
      if (savedViews.isNotEmpty)
        AppleToolbarItem(
          icon: Icons.more_horiz_rounded,
          label: 'Gestionar vistas',
          onTap: onManageViews,
        ),
      AppleToolbarItem(
        icon: Icons.ios_share_rounded,
        label: 'Compartir',
        shortcut: 'Ctrl/Cmd+Shift+E',
        onTap: onShare,
      ),
      AppleToolbarItem(
        icon: Icons.format_line_spacing_rounded,
        label: 'Densidad',
        onTap: onDensity,
      ),
      AppleToolbarItem(
        icon: Icons.functions_rounded,
        label: AppStrings.editorCompute,
        onTap: onCompute ?? () {},
        enabled: onCompute != null,
      ),
      AppleToolbarItem(
        icon: Icons.science_outlined,
        label: AppStrings.editorDiagnostics,
        onTap: onSmokeTest,
      ),
      AppleToolbarItem(
        icon: Icons.keyboard,
        label: 'Atajos',
        shortcut: 'Ctrl/Cmd+K',
        onTap: onPalette,
      ),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(12, top + 4, 12, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: palette.headerCardBg.withValues(
            alpha: palette.isLight ? 0.96 : 0.88,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: palette.headerCardBorder,
            width: math.max(palette.hairline, 0.8).toDouble(),
          ),
          boxShadow: [
            BoxShadow(
              color: palette.cellText.withValues(
                alpha: palette.isLight ? 0.04 : 0.16,
              ),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (ctx, cs) {
            final compact = cs.maxWidth < 980;
            final veryCompact = cs.maxWidth < 640;
            final titleSize = veryCompact ? 19.0 : 22.0;
            final pillGap = veryCompact ? 6.0 : 8.0;

            final titleField = TextField(
              controller: titleController,
              focusNode: titleFocus,
              onChanged: onTitleChanged,
              maxLines: 1,
              style: TextStyle(
                color: palette.fg,
                fontSize: titleSize,
                fontWeight: FontWeight.w800,
                height: 1.1,
                letterSpacing: 0,
              ),
              cursorColor: palette.accent,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: AppStrings.editorSheetNameHint,
                hintStyle: TextStyle(color: palette.fgMuted),
              ),
            );

            final statusRow = Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: compact ? WrapAlignment.start : WrapAlignment.end,
              children: [
                _SaveStatusChip(
                  palette: palette,
                  status: controller.saveStatus,
                ),
                _SyncStatusChip(
                  palette: palette,
                  status: controller.offlineStatus,
                  onTap: onOpenOfflineQueue,
                ),
                _InlineMetaChip(
                  palette: palette,
                  icon: Icons.access_time_rounded,
                  label: _formatLocalSaved(lastLocalSavedAt),
                ),
                _InlineMetaChip(
                  palette: palette,
                  icon: Icons.grid_3x3_rounded,
                  label: _selectionLabel(),
                ),
                if (selectedRowsCount > 1)
                  _InlineMetaChip(
                    palette: palette,
                    icon: Icons.checklist_rounded,
                    label: '$selectedRowsCount filas',
                  ),
                if (pendingOfflineCount > 0)
                  _InlineMetaChip(
                    palette: palette,
                    icon: Icons.cloud_upload_outlined,
                    label: '$pendingOfflineCount en cola',
                    onTap: onOpenOfflineQueue,
                  ),
                if (outboxPendingCount > 0)
                  _InlineMetaChip(
                    palette: palette,
                    icon: Icons.schedule_rounded,
                    label: 'Pendientes: $outboxPendingCount',
                  ),
                if (outboxErrorCount > 0)
                  _InlineMetaChip(
                    palette: palette,
                    icon: Icons.error_outline_rounded,
                    label: 'Error: $outboxErrorCount',
                  ),
                if (errorsCount > 0)
                  _InlineMetaChip(
                    palette: palette,
                    icon: Icons.rule_rounded,
                    label: '$errorsCount errores',
                  ),
              ],
            );

            final toolbar = Wrap(
              spacing: pillGap,
              runSpacing: 7,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FocusTraversalOrder(
                  order: const NumericFocusOrder(1.0),
                  child: _PillButton(
                    palette: palette,
                    filled: true,
                    icon: Icons.add_box_outlined,
                    label: '+ Registro',
                    semanticsLabel: 'Crear registro r\u00e1pido de campo',
                    tooltip: 'Crear un registro en modo campo',
                    onTap: onQuickCapture,
                  ),
                ),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(1.1),
                  child: _PillButton(
                    palette: palette,
                    filled: false,
                    icon: Icons.check_circle_outline_rounded,
                    label: AppStrings.editorSave,
                    semanticsLabel: AppStrings.semEditorSave,
                    tooltip: 'Guardar cambios locales',
                    onTap: onSave,
                  ),
                ),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(1.2),
                  child: _PillButton(
                    palette: palette,
                    filled: false,
                    icon: Icons.ios_share_rounded,
                    label: AppStrings.editorExport,
                    semanticsLabel: AppStrings.semEditorExport,
                    tooltip: 'Exportar o compartir planilla',
                    onTap: onExport,
                  ),
                ),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(1.3),
                  child: _PillButton(
                    palette: palette,
                    filled: false,
                    icon: Icons.search_rounded,
                    label: AppStrings.editorSearch,
                    semanticsLabel: 'Buscar en la planilla',
                    tooltip: 'Buscar en la planilla',
                    onTap: onSearch,
                  ),
                ),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(1.4),
                  child: _PillButton(
                    palette: palette,
                    filled: false,
                    icon: Icons.view_column_rounded,
                    label: 'Columnas',
                    semanticsLabel: 'Configurar columnas',
                    tooltip: 'Configurar columnas',
                    onTap: onColumns,
                  ),
                ),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(1.5),
                  child: _ToolbarMenuButton(
                    palette: palette,
                    icon: Icons.attachment_rounded,
                    label: 'Evidencia',
                    items: evidenceItems,
                  ),
                ),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(1.6),
                  child: _ToolbarMenuButton(
                    palette: palette,
                    icon: Icons.fact_check_outlined,
                    label: 'Revisar',
                    items: reviewItems,
                  ),
                ),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(1.7),
                  child: _ToolbarMenuButton(
                    palette: palette,
                    icon: Icons.more_horiz_rounded,
                    label: 'M\u00e1s',
                    items: moreItems,
                  ),
                ),
              ],
            );

            return FocusTraversalGroup(
              policy: OrderedTraversalPolicy(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (compact) ...[
                    titleField,
                    const SizedBox(height: 7),
                    statusRow,
                  ] else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: titleField),
                        const SizedBox(width: 14),
                        Flexible(flex: 2, child: statusRow),
                      ],
                    ),
                  const SizedBox(height: 9),
                  toolbar,
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ToolbarMenuButton extends StatelessWidget {
  const _ToolbarMenuButton({
    required this.palette,
    required this.icon,
    required this.label,
    required this.items,
  });

  final _SheetPalette palette;
  final IconData icon;
  final String label;
  final List<AppleToolbarItem> items;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: label,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      padding: EdgeInsets.zero,
      color: palette.menuBg,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: palette.border,
          width: math.max(palette.hairline, 0.8).toDouble(),
        ),
      ),
      onSelected: (index) {
        final item = items[index];
        if (item.enabled) {
          item.onTap();
        } else {
          item.onDisabledTap?.call();
        }
      },
      itemBuilder: (context) {
        return <PopupMenuEntry<int>>[
          for (var i = 0; i < items.length; i++)
            PopupMenuItem<int>(
              value: i,
              enabled: items[i].enabled || items[i].onDisabledTap != null,
              child: _ToolbarMenuEntry(
                palette: palette,
                item: items[i],
              ),
            ),
        ];
      },
      child: _ToolbarMenuPill(
        palette: palette,
        icon: icon,
        label: label,
      ),
    );
  }
}

class _ToolbarMenuEntry extends StatelessWidget {
  const _ToolbarMenuEntry({
    required this.palette,
    required this.item,
  });

  final _SheetPalette palette;
  final AppleToolbarItem item;

  @override
  Widget build(BuildContext context) {
    final enabled = item.enabled || item.onDisabledTap != null;
    final fg = enabled ? palette.fg : palette.fgMuted.withValues(alpha: 0.54);
    return Opacity(
      opacity: enabled ? 1 : 0.7,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 190, maxWidth: 280),
        child: Row(
          children: [
            Icon(item.icon, size: 18, color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  letterSpacing: 0,
                ),
              ),
            ),
            if ((item.shortcut ?? '').trim().isNotEmpty) ...[
              const SizedBox(width: 12),
              Text(
                item.shortcut!.trim(),
                style: TextStyle(
                  color: palette.fgMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ToolbarMenuPill extends StatelessWidget {
  const _ToolbarMenuPill({
    required this.palette,
    required this.icon,
    required this.label,
  });

  final _SheetPalette palette;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: palette.pillBtnBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: palette.pillBtnBorder,
          width: math.max(palette.hairline, 0.8).toDouble(),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: palette.fg),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: palette.fg,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              height: 1.05,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(width: 5),
          Icon(Icons.expand_more_rounded, size: 16, color: palette.fgMuted),
        ],
      ),
    );
  }
}

class _MobileCompactHeader extends StatelessWidget {
  const _MobileCompactHeader({
    required this.palette,
    required this.title,
    required this.controller,
    required this.pendingRequired,
    required this.pendingOfflineCount,
    required this.outboxPendingCount,
    required this.outboxErrorCount,
    required this.selectedRow,
    required this.selectedCol,
    required this.onSave,
    required this.onExport,
    required this.onMenu,
    required this.onOpenOfflineQueue,
    required this.lastLocalSavedAt,
    this.onBackToSheets,
  });

  final _SheetPalette palette;
  final String title;
  final EditorController controller;
  final int pendingRequired;
  final int pendingOfflineCount;
  final int outboxPendingCount;
  final int outboxErrorCount;
  final int selectedRow;
  final int selectedCol;
  final VoidCallback onSave;
  final VoidCallback onExport;
  final VoidCallback onMenu;
  final VoidCallback onOpenOfflineQueue;
  final DateTime? lastLocalSavedAt;
  final VoidCallback? onBackToSheets;

  String _formatLocalSaved(DateTime? value) {
    if (value == null) return 'Último guardado local: --:--';
    final local = value.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return 'Último guardado local: $hh:$mm';
  }

  static String _columnLabel(int col) {
    var value = col + 1;
    final out = StringBuffer();
    while (value > 0) {
      final rem = (value - 1) % 26;
      out.writeCharCode(65 + rem);
      value = (value - 1) ~/ 26;
    }
    return out.toString().split('').reversed.join();
  }

  @override
  Widget build(BuildContext context) {
    final label = title.trim().isEmpty ? 'Planilla' : title.trim();

    return ValueListenableBuilder<EditorSaveSnapshot>(
      valueListenable: controller.saveStatus,
      builder: (context, snap, _) {
        return ValueListenableBuilder<OfflineSyncSnapshot>(
          valueListenable: controller.offlineStatus,
          builder: (context, offline, __) {
            String saveLabel;
            switch (snap.state) {
              case EditorSaveState.saving:
                saveLabel = 'Guardando';
                break;
              case EditorSaveState.dirty:
                saveLabel = 'Sin guardar...';
                break;
              case EditorSaveState.saved:
                saveLabel = 'Guardado';
                break;
              case EditorSaveState.idle:
                saveLabel = 'Listo';
                break;
            }

            final pendingLabel =
                pendingRequired > 0 ? '$pendingRequired errores' : null;
            final queueLabel =
                pendingOfflineCount > 0 ? 'Cola $pendingOfflineCount' : null;
            final outboxPendingLabel = outboxPendingCount > 0
                ? '$outboxPendingCount pendientes'
                : null;
            final outboxErrorLabel =
                outboxErrorCount > 0 ? '$outboxErrorCount con error' : null;
            final offlineLabel = offline.message?.trim().isNotEmpty == true
                ? offline.message!.trim()
                : 'Sincronizado';
            final localLabel =
                _formatLocalSaved(lastLocalSavedAt ?? snap.savedAt)
                    .replaceFirst('Último guardado local: ', 'Local: ');
            final activeCell = (selectedRow >= 0 && selectedCol >= 0)
                ? '${_columnLabel(selectedCol)}${selectedRow + 1}'
                : '--';
            final saveIcon = switch (snap.state) {
              EditorSaveState.saving => Icons.sync_rounded,
              EditorSaveState.dirty => Icons.edit_note_rounded,
              EditorSaveState.saved => Icons.check_circle_rounded,
              EditorSaveState.idle => Icons.task_alt_rounded,
            };
            final syncIcon = switch (offline.state) {
              OfflineSyncState.offline => Icons.cloud_off_rounded,
              OfflineSyncState.pending => Icons.schedule_send_rounded,
              OfflineSyncState.syncing => Icons.sync_rounded,
              OfflineSyncState.synced => Icons.cloud_done_rounded,
              OfflineSyncState.failed => Icons.sync_problem_rounded,
            };

            return Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: GlassSurface(
                radius: 22,
                blurSigma: palette.isLight ? 13 : 10,
                backgroundColor: palette.headerCardBg
                    .withValues(alpha: palette.isLight ? 0.78 : 0.6),
                borderColor: palette.headerCardBorder
                    .withValues(alpha: palette.isLight ? 0.55 : 0.84),
                shadowColor: Colors.black
                    .withValues(alpha: palette.isLight ? 0.08 : 0.26),
                shadowBlur: 18,
                shadowOffset: const Offset(0, 8),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (onBackToSheets != null) ...[
                          _MobilePanelIconButton(
                            icon: Icons.arrow_back_rounded,
                            tooltip: 'Mis planillas',
                            onTap: onBackToSheets,
                            palette: palette,
                            iconSize: 20,
                            splashRadius: 18,
                            padding: const EdgeInsets.all(6),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.fg,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              height: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _SaveStatusChip(
                          palette: palette,
                          status: controller.saveStatus,
                        ),
                        const SizedBox(width: 4),
                        _MobilePanelIconButton(
                          icon: Icons.more_horiz_rounded,
                          tooltip: AppStrings.editorOptions,
                          onTap: onMenu,
                          palette: palette,
                          iconSize: 18,
                          splashRadius: 16,
                          padding: const EdgeInsets.all(4),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MobileStatusPill(
                          palette: palette,
                          icon: saveIcon,
                          label: saveLabel,
                          emphasized: snap.state == EditorSaveState.saved,
                        ),
                        if (pendingLabel != null)
                          _MobileStatusPill(
                            palette: palette,
                            icon: Icons.error_outline_rounded,
                            label: pendingLabel,
                            tone: _MobileStatusTone.danger,
                          ),
                        if (queueLabel != null)
                          _MobileStatusPill(
                            palette: palette,
                            icon: Icons.outbox_rounded,
                            label: queueLabel,
                          ),
                        if (outboxPendingLabel != null)
                          _MobileStatusPill(
                            palette: palette,
                            icon: Icons.schedule_send_rounded,
                            label: outboxPendingLabel,
                          ),
                        if (outboxErrorLabel != null)
                          _MobileStatusPill(
                            palette: palette,
                            icon: Icons.sync_problem_rounded,
                            label: outboxErrorLabel,
                            tone: _MobileStatusTone.danger,
                          ),
                        _MobileStatusPill(
                          palette: palette,
                          icon: Icons.grid_on_rounded,
                          label: activeCell,
                        ),
                        _MobileStatusPill(
                          palette: palette,
                          icon: Icons.access_time_rounded,
                          label: localLabel,
                        ),
                        _MobileStatusPill(
                          palette: palette,
                          icon: syncIcon,
                          label: offlineLabel,
                          tone: offline.state == OfflineSyncState.failed
                              ? _MobileStatusTone.danger
                              : _MobileStatusTone.neutral,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: AppStrings.editorSave,
                            icon: Icons.check_circle_outline_rounded,
                            variant: AppButtonVariant.secondary,
                            size: AppButtonSize.sm,
                            onPressed: onSave,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppButton(
                            label: 'Cola',
                            icon: Icons.sync_alt_rounded,
                            variant: AppButtonVariant.secondary,
                            size: AppButtonSize.sm,
                            onPressed: onOpenOfflineQueue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppButton(
                            label: AppStrings.editorExport,
                            icon: Icons.ios_share_rounded,
                            variant: AppButtonVariant.ghost,
                            size: AppButtonSize.sm,
                            onPressed: onExport,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

enum _MobileStatusTone { neutral, danger }

class _MobileStatusPill extends StatelessWidget {
  const _MobileStatusPill({
    required this.palette,
    required this.icon,
    required this.label,
    this.tone = _MobileStatusTone.neutral,
    this.emphasized = false,
  });

  final _SheetPalette palette;
  final IconData icon;
  final String label;
  final _MobileStatusTone tone;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final danger = tone == _MobileStatusTone.danger;
    final bg = danger
        ? palette.dangerBg.withValues(alpha: palette.isLight ? 0.82 : 0.5)
        : emphasized
            ? palette.statusBg.withValues(alpha: palette.isLight ? 0.92 : 0.62)
            : palette.chipBg.withValues(alpha: palette.isLight ? 0.84 : 0.34);
    final fg = danger
        ? palette.dangerFg
        : emphasized
            ? palette.statusFg
            : palette.fgMuted;
    final border = danger
        ? palette.dangerFg.withValues(alpha: 0.22)
        : palette.chipBorder.withValues(alpha: palette.isLight ? 0.55 : 0.42);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 156),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileHeaderCollapsedPill extends StatelessWidget {
  const _MobileHeaderCollapsedPill({
    required this.palette,
    required this.title,
    required this.selectedRow,
    required this.selectedCol,
    required this.onMenu,
    this.onBackToSheets,
  });

  final _SheetPalette palette;
  final String title;
  final int selectedRow;
  final int selectedCol;
  final VoidCallback onMenu;
  final VoidCallback? onBackToSheets;

  static String _columnLabel(int col) {
    var value = col + 1;
    final out = StringBuffer();
    while (value > 0) {
      final rem = (value - 1) % 26;
      out.writeCharCode(65 + rem);
      value = (value - 1) ~/ 26;
    }
    return out.toString().split('').reversed.join();
  }

  @override
  Widget build(BuildContext context) {
    final safeTitle = title.trim().isEmpty ? 'Planilla' : title.trim();
    final activeCell = (selectedRow >= 0 && selectedCol >= 0)
        ? '${_columnLabel(selectedCol)}${selectedRow + 1}'
        : '--';

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GlassSurface(
          radius: 999,
          blurSigma: palette.isLight ? 10 : 8,
          backgroundColor: palette.headerCardBg
              .withValues(alpha: palette.isLight ? 0.72 : 0.56),
          borderColor: palette.headerCardBorder
              .withValues(alpha: palette.isLight ? 0.5 : 0.84),
          shadowColor:
              Colors.black.withValues(alpha: palette.isLight ? 0.06 : 0.22),
          shadowBlur: 12,
          shadowOffset: const Offset(0, 6),
          padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onBackToSheets != null) ...[
                _MobilePanelIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Mis planillas',
                  onTap: onBackToSheets,
                  palette: palette,
                  iconSize: 16,
                  splashRadius: 14,
                  padding: const EdgeInsets.all(4),
                ),
                const SizedBox(width: 4),
              ] else ...[
                Container(
                  width: 16,
                  height: 3,
                  decoration: BoxDecoration(
                    color: palette.fgMuted.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(
                  '$safeTitle | $activeCell',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.fgMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.8,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _MobilePanelIconButton(
                icon: Icons.more_horiz_rounded,
                tooltip: AppStrings.editorOptions,
                onTap: onMenu,
                palette: palette,
                iconSize: 18,
                splashRadius: 16,
                padding: const EdgeInsets.all(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineMetaChip extends StatelessWidget {
  const _InlineMetaChip({
    required this.palette,
    required this.icon,
    required this.label,
    this.onTap,
  });

  final _SheetPalette palette;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: palette.hintBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border, width: palette.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: palette.fgMuted),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: palette.fgMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: 1.05,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: content,
    );
  }
}

class _PillButton extends StatefulWidget {
  const _PillButton({
    required this.palette,
    required this.filled,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.semanticsLabel,
    this.tooltip,
  });

  final _SheetPalette palette;
  final bool filled;
  final IconData icon;
  final String label;
  final String semanticsLabel;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton> {
  bool _hovered = false;
  bool _pressed = false;

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;

    final baseBg =
        widget.filled ? widget.palette.accent : widget.palette.pillBtnBg;
    final bg = _pressed
        ? baseBg.withValues(alpha: widget.filled ? 0.85 : 0.72)
        : (_hovered
            ? baseBg.withValues(alpha: widget.filled ? 0.94 : 0.9)
            : baseBg);

    final fg = widget.filled ? Colors.white : widget.palette.fg;

    final button = Opacity(
      opacity: disabled ? 0.45 : 1.0,
      child: MouseRegion(
        onEnter: disabled ? null : (_) => _setHovered(true),
        onExit: disabled ? null : (_) => _setHovered(false),
        child: AnimatedScale(
          duration: AppMotion.quick,
          curve: AppMotion.standardOut,
          scale: _pressed ? 0.985 : 1.0,
          child: AnimatedContainer(
            duration: AppMotion.quick,
            curve: AppMotion.standardOut,
            decoration: const BoxDecoration(),
            child: InkWell(
              onTap: disabled ? null : widget.onTap,
              onHighlightChanged: disabled ? null : _setPressed,
              borderRadius: BorderRadius.circular(999),
              child: Semantics(
                button: true,
                label: widget.semanticsLabel,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: widget.palette.pillBtnBorder,
                        width: widget.palette.hairline),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.icon, size: 17, color: fg),
                      const SizedBox(width: 7),
                      Text(
                        widget.label,
                        style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          height: 1.05,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final tip = widget.tooltip?.trim() ?? '';
    if (tip.isEmpty) return button;
    return Tooltip(message: tip, child: button);
  }
}

// ============================== UI: Grid ==================================

typedef _SelectCell = void Function(int r, int c);
typedef _EditCell = void Function(int r, int c, double cellWidth);
typedef _EditHeader = void Function(int c, double headerWidth);
typedef _ContextMenu = void Function(Offset pos, int r, int c, bool isHeader);
