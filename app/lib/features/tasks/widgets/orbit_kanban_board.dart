import 'package:flutter/material.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/widgets/orbit_attention_card.dart';
import 'package:orbit_app/core/widgets/orbit_formatters.dart';
import 'package:orbit_app/core/widgets/orbit_status_badge.dart';
import 'package:orbit_app/features/tasks/widgets/orbit_revision_dialog.dart';

/// Urutan resmi 4 kolom Kanban Workflow D.2.
const List<String> orbitKanbanColumnOrder = ['todo', 'doing', 'revisi', 'done'];

/// Memfilter tugas `done` agar default hanya menampilkan 14 hari terakhir
/// kecuali [showAllDone] diaktifkan.
List<LocalTask> filterDoneTasksForKanban(
  List<LocalTask> doneTasks, {
  required bool showAllDone,
  DateTime? now,
}) {
  if (showAllDone) return doneTasks;
  final current = now ?? DateTime.now();
  final cutoff = current.subtract(const Duration(days: 14));
  return doneTasks.where((t) {
    final refDate = t.completedAt ?? t.statusChangedAt;
    if (refDate == null) return false;
    return !refDate.isBefore(cutoff);
  }).toList();
}

int _priorityRank(String priority) {
  switch (priority) {
    case 'tinggi':
      return 0;
    case 'sedang':
      return 1;
    case 'rendah':
      return 2;
    default:
      return 3;
  }
}

/// Mengurutkan tugas pada kolom Kanban: prioritas tertinggi -> sortOrder -> tenggat terdekat.
List<LocalTask> sortKanbanColumnTasks(List<LocalTask> items) {
  final list = List<LocalTask>.from(items);
  list.sort((a, b) {
    final pCmp = _priorityRank(a.priority).compareTo(_priorityRank(b.priority));
    if (pCmp != 0) return pCmp;
    final sCmp = a.sortOrder.compareTo(b.sortOrder);
    if (sCmp != 0) return sCmp;
    if (a.dueAt != null && b.dueAt != null) {
      return a.dueAt!.compareTo(b.dueAt!);
    }
    if (a.dueAt != null) return -1;
    if (b.dueAt != null) return 1;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });
  return list;
}

/// Papan Kanban horizontal scrollable 4 kolom D.2 untuk layar mobile.
class OrbitKanbanBoard extends StatefulWidget {
  final List<LocalTask> tasks;
  final Map<String, LocalProject> projectsById;
  final ValueChanged<LocalTask> onTapTask;
  final Future<void> Function(LocalTask task, String toStatus, String? note)
      onChangeStatus;
  final DateTime? referenceNow;

  const OrbitKanbanBoard({
    super.key,
    required this.tasks,
    required this.projectsById,
    required this.onTapTask,
    required this.onChangeStatus,
    this.referenceNow,
  });

  @override
  State<OrbitKanbanBoard> createState() => _OrbitKanbanBoardState();
}

class _OrbitKanbanBoardState extends State<OrbitKanbanBoard> {
  bool _showAllDone = false;

  String _normalizeColumnStatus(String raw) {
    switch (raw) {
      case 'doing':
      case 'revisi':
      case 'done':
        return raw;
      default:
        return 'todo';
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.referenceNow ?? DateTime.now();
    final grouped = <String, List<LocalTask>>{
      for (final col in orbitKanbanColumnOrder) col: [],
    };
    for (final task in widget.tasks) {
      final col = _normalizeColumnStatus(task.status);
      grouped[col]!.add(task);
    }

    final allDoneSorted = sortKanbanColumnTasks(grouped['done']!);
    final visibleDone = filterDoneTasksForKanban(
      allDoneSorted,
      showAllDone: _showAllDone,
      now: now,
    );
    final hiddenDoneCount = allDoneSorted.length - visibleDone.length;

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: orbitKanbanColumnOrder.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (context, index) {
        final colStatus = orbitKanbanColumnOrder[index];
        final isDoneCol = colStatus == 'done';
        final colItems = isDoneCol
            ? visibleDone
            : sortKanbanColumnTasks(grouped[colStatus]!);

        return _KanbanColumn(
          status: colStatus,
          items: colItems,
          totalCount: isDoneCol ? allDoneSorted.length : colItems.length,
          projectsById: widget.projectsById,
          now: now,
          onTapTask: widget.onTapTask,
          onChangeStatus: widget.onChangeStatus,
          isDoneCol: isDoneCol,
          showAllDone: _showAllDone,
          hiddenDoneCount: hiddenDoneCount,
          onToggleShowAllDone: isDoneCol && (hiddenDoneCount > 0 || _showAllDone)
              ? () => setState(() => _showAllDone = !_showAllDone)
              : null,
        );
      },
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  final String status;
  final List<LocalTask> items;
  final int totalCount;
  final Map<String, LocalProject> projectsById;
  final DateTime now;
  final ValueChanged<LocalTask> onTapTask;
  final Future<void> Function(LocalTask task, String toStatus, String? note)
      onChangeStatus;
  final bool isDoneCol;
  final bool showAllDone;
  final int hiddenDoneCount;
  final VoidCallback? onToggleShowAllDone;

  const _KanbanColumn({
    required this.status,
    required this.items,
    required this.totalCount,
    required this.projectsById,
    required this.now,
    required this.onTapTask,
    required this.onChangeStatus,
    required this.isDoneCol,
    required this.showAllDone,
    required this.hiddenDoneCount,
    this.onToggleShowAllDone,
  });

  @override
  Widget build(BuildContext context) {
    final borderCol = AppColors.borderColor(context);
    final columnBg = AppColors.subtleColor(context);
    final textMuted = AppColors.textMutedColor(context);

    return Container(
      width: 288,
      decoration: BoxDecoration(
        color: columnBg,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(color: borderCol, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(
              children: [
                OrbitTaskStatusBadge(status: status),
                const Spacer(),
                Text(
                  isDoneCol && !showAllDone && hiddenDoneCount > 0
                      ? '${items.length}/$totalCount'
                      : '${items.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textMuted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: borderCol),
          Expanded(
            child: items.isEmpty && onToggleShowAllDone == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        isDoneCol
                            ? 'Belum ada tugas selesai 14 hari terakhir.'
                            : 'Tidak ada tugas di kolom ini.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: textMuted),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount:
                        items.length + (onToggleShowAllDone != null ? 1 : 0),
                    itemBuilder: (context, idx) {
                      if (onToggleShowAllDone != null && idx == items.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 44),
                              side: BorderSide(color: borderCol),
                              backgroundColor: AppColors.surfaceColor(context),
                            ),
                            onPressed: onToggleShowAllDone,
                            child: Text(
                              showAllDone
                                  ? 'Tampilkan 14 hari terakhir'
                                  : 'Lihat semua selesai (+$hiddenDoneCount)',
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ),
                        );
                      }

                      final task = items[idx];
                      final project = task.projectId != null
                          ? projectsById[task.projectId!]
                          : null;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _KanbanTaskCard(
                          task: task,
                          projectName: project?.name,
                          now: now,
                          onTap: () => onTapTask(task),
                          onMoveStatus: () => showOrbitStatusPickerSheet(
                            context,
                            task: task,
                            onSelected: (toStatus, note) =>
                                onChangeStatus(task, toStatus, note),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _KanbanTaskCard extends StatelessWidget {
  final LocalTask task;
  final String? projectName;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback onMoveStatus;

  const _KanbanTaskCard({
    required this.task,
    this.projectName,
    required this.now,
    required this.onTap,
    required this.onMoveStatus,
  });

  String _priorityLabel(String priority) {
    switch (priority) {
      case 'tinggi':
        return 'Tinggi';
      case 'rendah':
        return 'Rendah';
      default:
        return 'Sedang';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderCol = AppColors.borderColor(context);
    final surface = AppColors.surfaceColor(context);
    final textPrimary = AppColors.textPrimaryColor(context);
    final textSecondary = AppColors.textSecondaryColor(context);
    final isOverdue = isOrbitTaskOverdue(task, now: now);
    final isStagnant = isOrbitTaskStagnant(task, now: now);

    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(color: borderCol, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Judul tugas
              Text(
                task.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                  decoration:
                      task.status == 'done' ? TextDecoration.lineThrough : null,
                ),
              ),
              const SizedBox(height: 8),

              // Proyek + Kind + Prioritas
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  OrbitKindBadge(kind: task.kind),
                  OrbitStatusBadge(
                    label: _priorityLabel(task.priority),
                    variant: task.priority == 'tinggi'
                        ? OrbitBadgeVariant.expense
                        : OrbitBadgeVariant.neutral,
                  ),
                  if (projectName != null && projectName!.isNotEmpty)
                    OrbitStatusBadge(label: projectName!),
                ],
              ),

              // Sinyal Revisi & Macet >5 hari
              if (task.revisionCount > 0 || isStagnant) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (task.revisionCount > 0)
                      OrbitStatusBadge(
                        label: 'Revisi ${task.revisionCount} kali',
                        variant: OrbitBadgeVariant.warning,
                      ),
                    if (isStagnant)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.warningSubtleDark
                              : AppColors.warningSubtleLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.warningColor(context)
                                .withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          'Macet >5 hari',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.warningColor(context),
                          ),
                        ),
                      ),
                  ],
                ),
              ],

              const SizedBox(height: 10),

              // Progress bar + persentase
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (task.progressPercent.clamp(0, 100)) / 100,
                        minHeight: 5,
                        backgroundColor: AppColors.subtleColor(context),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          task.status == 'done'
                              ? AppColors.incomeColor(context)
                              : AppColors.accentColor(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${task.progressPercent}%',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Tenggat + tombol Pindah status (>= 44x44 touch target)
              Row(
                children: [
                  Expanded(
                    child: task.dueAt != null
                        ? Row(
                            children: [
                              Icon(
                                Icons.schedule_outlined,
                                size: 13,
                                color: isOverdue
                                    ? AppColors.expenseColor(context)
                                    : textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  formatDateIndoShort(task.dueAt!),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: isOverdue
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: isOverdue
                                        ? AppColors.expenseColor(context)
                                        : textSecondary,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Text(
                            'Tanpa tenggat',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMutedColor(context),
                            ),
                          ),
                  ),
                  InkWell(
                    onTap: onMoveStatus,
                    borderRadius: BorderRadius.circular(6),
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(minWidth: 44, minHeight: 44),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.swap_horiz_rounded,
                              size: 16,
                              color: AppColors.accentColor(context),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Pindah status',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accentColor(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
