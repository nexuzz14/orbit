import 'package:flutter/material.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';

/// Definisi opsi mode tampilan pada ViewSwitcher.
class OrbitViewOption {
  final String id;
  final String label;
  final IconData icon;

  const OrbitViewOption({
    required this.id,
    required this.label,
    required this.icon,
  });
}

/// Kontrol segmen mode tampilan (`Daftar | Papan | Proyek`) bergaya Notion.
class OrbitViewSwitcher extends StatelessWidget {
  final String activeViewMode;
  final ValueChanged<String> onChanged;
  final List<OrbitViewOption> options;

  const OrbitViewSwitcher({
    super.key,
    required this.activeViewMode,
    required this.onChanged,
    this.options = const [
      OrbitViewOption(
        id: 'list',
        label: 'Daftar',
        icon: Icons.format_list_bulleted_rounded,
      ),
      OrbitViewOption(
        id: 'board',
        label: 'Papan',
        icon: Icons.view_kanban_outlined,
      ),
      OrbitViewOption(
        id: 'timeline',
        label: 'Proyek',
        icon: Icons.folder_copy_outlined,
      ),
    ],
  });

  @override
  Widget build(BuildContext context) {
    final borderCol = AppColors.borderColor(context);
    final surface = AppColors.surfaceColor(context);
    final subtle = AppColors.subtleColor(context);
    final accent = AppColors.accentColor(context);
    final textPrimary = AppColors.textPrimaryColor(context);
    final textSecondary = AppColors.textSecondaryColor(context);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: subtle,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: borderCol, width: 1),
      ),
      child: Row(
        children: options.map((opt) {
          final isSelected = activeViewMode == opt.id;
          return Expanded(
            child: Semantics(
              button: true,
              selected: isSelected,
              label: 'Tampilan ${opt.label}',
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                onTap: () => onChanged(opt.id),
                child: AnimatedContainer(
                  duration: AppTokens.animFast,
                  curve: Curves.easeOut,
                  constraints: const BoxConstraints(
                    minHeight: AppTokens.minTouchTarget,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                    border: isSelected
                        ? Border.all(color: borderCol, width: 1)
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        opt.icon,
                        size: 16,
                        color: isSelected ? accent : textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          opt.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? textPrimary : textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Bilah chip Saved Views beserta aksi simpan, sematkan ke drawer, dan hapus.
class OrbitSavedViewsBar extends StatelessWidget {
  final List<LocalSavedView> views;
  final String? activeViewId;
  final ValueChanged<LocalSavedView?> onSelectView;
  final VoidCallback onSaveCurrentView;
  final void Function(LocalSavedView view)? onTogglePin;
  final void Function(LocalSavedView view)? onDeleteView;

  const OrbitSavedViewsBar({
    super.key,
    required this.views,
    required this.activeViewId,
    required this.onSelectView,
    required this.onSaveCurrentView,
    this.onTogglePin,
    this.onDeleteView,
  });

  @override
  Widget build(BuildContext context) {
    final borderCol = AppColors.borderColor(context);
    final accent = AppColors.accentColor(context);
    final accentSoft = accent.withValues(alpha: 0.12);
    final textPrimary = AppColors.textPrimaryColor(context);

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _SavedViewChip(
            label: 'Semua Tugas',
            selected: activeViewId == null,
            pinned: false,
            onTap: () => onSelectView(null),
          ),
          const SizedBox(width: 6),
          ...views.map((view) {
            final isSelected = activeViewId == view.id;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _SavedViewChip(
                label: view.name,
                selected: isSelected,
                pinned: view.isPinned,
                onTap: () => onSelectView(view),
                onLongPress: (onTogglePin != null || onDeleteView != null)
                    ? () => _showViewMenu(context, view)
                    : null,
              ),
            );
          }),
          Semantics(
            button: true,
            label: 'Simpan Tampilan',
            child: InkWell(
              onTap: onSaveCurrentView,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: AppTokens.minTouchTarget,
                  minWidth: AppTokens.minTouchTarget,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accentSoft,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderCol),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bookmark_add_outlined, size: 15, color: accent),
                    const SizedBox(width: 5),
                    Text(
                      'Simpan Tampilan',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showViewMenu(
    BuildContext context,
    LocalSavedView view,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    view.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryColor(ctx),
                    ),
                  ),
                ),
              ),
              if (onTogglePin != null)
                ListTile(
                  leading: Icon(
                    view.isPinned
                        ? Icons.push_pin_rounded
                        : Icons.push_pin_outlined,
                    color: AppColors.accentColor(ctx),
                  ),
                  title: Text(
                    view.isPinned
                        ? 'Lepas sematan dari Drawer'
                        : 'Sematkan ke atas Drawer',
                  ),
                  onTap: () => Navigator.pop(ctx, 'pin'),
                ),
              if (onDeleteView != null)
                ListTile(
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.expenseColor(ctx),
                  ),
                  title: Text(
                    'Hapus Tampilan',
                    style: TextStyle(color: AppColors.expenseColor(ctx)),
                  ),
                  onTap: () => Navigator.pop(ctx, 'delete'),
                ),
            ],
          ),
        ),
      ),
    );
    if (action == 'pin') {
      onTogglePin?.call(view);
    } else if (action == 'delete') {
      onDeleteView?.call(view);
    }
  }
}

class _SavedViewChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool pinned;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _SavedViewChip({
    required this.label,
    required this.selected,
    required this.pinned,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final borderCol = AppColors.borderColor(context);
    final surface = AppColors.surfaceColor(context);
    final accent = AppColors.accentColor(context);
    final accentSoft = accent.withValues(alpha: 0.12);
    final textPrimary = AppColors.textPrimaryColor(context);
    final textSecondary = AppColors.textSecondaryColor(context);

    return Center(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppTokens.minTouchTarget,
              minWidth: AppTokens.minTouchTarget,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
            decoration: BoxDecoration(
              color: selected ? accentSoft : surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? accent : borderCol,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pinned) ...[
                  Icon(
                    Icons.push_pin_outlined,
                    size: 13,
                    color: selected ? accent : textSecondary,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? textPrimary : textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
