import 'package:flutter/material.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/widgets/orbit_attention_card.dart';
import 'package:orbit_app/core/widgets/orbit_formatters.dart';
import 'package:orbit_app/core/widgets/orbit_status_badge.dart';

/// Baris tugas bergaya Notion untuk Daftar Tugas dengan status D.2,
/// indikator progres, revisi, macet > 5 hari, dan tombol pindah status.
class OrbitTaskCard extends StatelessWidget {
  final LocalTask task;
  final VoidCallback onToggleDone;
  final VoidCallback? onTap;
  final VoidCallback? onMoveStatus;
  final String? projectName;
  final int checklistTotal;
  final int checklistDone;
  final int subtaskTotal;
  final int subtaskDone;

  const OrbitTaskCard({
    super.key,
    required this.task,
    required this.onToggleDone,
    this.onTap,
    this.onMoveStatus,
    this.projectName,
    this.checklistTotal = 0,
    this.checklistDone = 0,
    this.subtaskTotal = 0,
    this.subtaskDone = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = task.status == 'done';
    final isOverdue = isOrbitTaskOverdue(task);
    final isStagnant = isOrbitTaskStagnant(task);
    final borderCol = AppColors.borderColor(context);
    final surface = AppColors.surfaceColor(context);
    final textPrimary = AppColors.textPrimaryColor(context);
    final textSecondary = AppColors.textSecondaryColor(context);
    final textMuted = AppColors.textMutedColor(context);

    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(AppTokens.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radiusLg),
            border: Border.all(color: borderCol, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Touch target >= 44x44px untuk checkbox selesai
              InkWell(
                onTap: onToggleDone,
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: isDone
                            ? AppColors.accentColor(context)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDone
                              ? AppColors.accentColor(context)
                              : borderCol,
                          width: 1.5,
                        ),
                      ),
                      child: isDone
                          ? const Icon(
                              Icons.check_rounded,
                              size: 15,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: isDone ? textMuted : textPrimary,
                              decoration:
                                  isDone ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        if (onMoveStatus != null)
                          IconButton(
                            tooltip: 'Pindah status',
                            constraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.more_horiz_rounded,
                              size: 20,
                              color: textSecondary,
                            ),
                            onPressed: onMoveStatus,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OrbitTaskStatusBadge(status: task.status, compact: true),
                        OrbitKindBadge(kind: task.kind),
                        if (projectName != null && projectName!.isNotEmpty)
                          OrbitStatusBadge(label: projectName!),
                        if (task.priority == 'tinggi')
                          const OrbitStatusBadge(
                            label: 'Tinggi',
                            variant: OrbitBadgeVariant.expense,
                          ),
                        if (task.revisionCount > 0)
                          OrbitStatusBadge(
                            label: 'Revisi ${task.revisionCount} kali',
                            variant: OrbitBadgeVariant.warning,
                          ),
                        if (isStagnant)
                          const OrbitStatusBadge(
                            label: 'Macet >5 hari',
                            variant: OrbitBadgeVariant.warning,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Progres ${task.progressPercent}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: textSecondary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        if (checklistTotal > 0)
                          Text(
                            'Checklist $checklistDone/$checklistTotal',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        if (subtaskTotal > 0)
                          Text(
                            'Subtugas $subtaskDone/$subtaskTotal',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        if (task.dueAt != null)
                          Text(
                            formatDateIndoShort(task.dueAt!),
                            style: TextStyle(
                              fontSize: 12,
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
                        if (task.recurrenceRuleJson != null &&
                            task.recurrenceRuleJson!.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.repeat_rounded,
                                  size: 13, color: textMuted),
                              const SizedBox(width: 3),
                              Text(
                                'Berulang',
                                style:
                                    TextStyle(fontSize: 11.5, color: textMuted),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
