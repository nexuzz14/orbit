import 'package:flutter/material.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';

/// Menentukan apakah sebuah tugas sudah melewati tenggatnya.
bool isOrbitTaskOverdue(LocalTask task, {DateTime? now}) {
  if (task.status == 'done' || task.dueAt == null) return false;
  final current = now ?? DateTime.now();
  final due = task.dueAt!;
  if (task.dueIsDateOnly) {
    final todayStart = DateTime(current.year, current.month, current.day);
    final dueDay = DateTime(due.year, due.month, due.day);
    return dueDay.isBefore(todayStart);
  }
  return due.isBefore(current);
}

/// Menentukan apakah sebuah tugas aktif macet lebih dari 5 hari pada status yang sama.
bool isOrbitTaskStagnant(
  LocalTask task, {
  DateTime? now,
  Duration threshold = const Duration(days: 5),
}) {
  if (task.status == 'done') return false;
  final changedAt = task.statusChangedAt;
  if (changedAt == null) return false;
  final current = now ?? DateTime.now();
  return current.difference(changedAt) > threshold;
}

/// Ringkasan item yang memerlukan perhatian segera pada layar Hari Ini.
class OrbitAttentionSummary {
  final int overdueCount;
  final int revisionCount;
  final int stagnantCount;
  final int conflictCount;

  const OrbitAttentionSummary({
    required this.overdueCount,
    required this.revisionCount,
    required this.stagnantCount,
    required this.conflictCount,
  });

  bool get isEmpty =>
      overdueCount == 0 &&
      revisionCount == 0 &&
      stagnantCount == 0 &&
      conflictCount == 0;

  int get totalSignals =>
      overdueCount + revisionCount + stagnantCount + conflictCount;
}

/// Menghitung sinyal perhatian dari daftar tugas aktif dan jadwal hari ini.
OrbitAttentionSummary computeOrbitAttentionSummary({
  required List<LocalTask> tasks,
  required List<LocalEvent> todayEvents,
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  int overdue = 0;
  int revision = 0;
  int stagnant = 0;

  for (final task in tasks) {
    if (task.deletedAt != null || task.status == 'done') continue;
    if (isOrbitTaskOverdue(task, now: current)) overdue++;
    if (task.status == 'revisi') revision++;
    if (isOrbitTaskStagnant(task, now: current)) stagnant++;
  }

  final timedEvents = todayEvents
      .where((e) => e.deletedAt == null && !e.allDay)
      .toList()
    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

  int conflicts = 0;
  for (int i = 0; i < timedEvents.length - 1; i++) {
    final cur = timedEvents[i];
    final next = timedEvents[i + 1];
    if (cur.endsAt.isAfter(next.startsAt)) {
      conflicts++;
    }
  }

  return OrbitAttentionSummary(
    overdueCount: overdue,
    revisionCount: revision,
    stagnantCount: stagnant,
    conflictCount: conflicts,
  );
}

/// Banner ringkasan perhatian Hari Ini (Terlambat, Perlu Revisi, Macet > 5 hari, Jadwal Bentrok).
class OrbitAttentionCard extends StatelessWidget {
  final OrbitAttentionSummary summary;
  final ValueChanged<String>? onTapSignal;

  const OrbitAttentionCard({
    super.key,
    required this.summary,
    this.onTapSignal,
  });

  @override
  Widget build(BuildContext context) {
    if (summary.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasUrgent = summary.overdueCount > 0 || summary.conflictCount > 0;
    final bg = hasUrgent
        ? (isDark ? AppColors.expenseSubtleDark : AppColors.expenseSubtleLight)
        : (isDark ? AppColors.warningSubtleDark : AppColors.warningSubtleLight);
    final accent = hasUrgent
        ? AppColors.expenseColor(context)
        : AppColors.warningColor(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(
          color: accent.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.priority_high_rounded, size: 17, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Perlu Perhatian Segera',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryColor(context),
                  ),
                ),
              ),
              Text(
                '${summary.totalSignals} item',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: accent,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (summary.overdueCount > 0)
                _AttentionPill(
                  label: 'Terlambat (${summary.overdueCount})',
                  fg: AppColors.expenseColor(context),
                  bg: AppColors.surfaceColor(context),
                  onTap: onTapSignal != null
                      ? () => onTapSignal!('overdue')
                      : null,
                ),
              if (summary.revisionCount > 0)
                _AttentionPill(
                  label: 'Perlu Revisi (${summary.revisionCount})',
                  fg: AppColors.getTaskStatusFg('revisi', isDark: isDark),
                  bg: AppColors.getTaskStatusBg('revisi', isDark: isDark),
                  onTap: onTapSignal != null
                      ? () => onTapSignal!('revisi')
                      : null,
                ),
              if (summary.stagnantCount > 0)
                _AttentionPill(
                  label: 'Macet > 5 hari (${summary.stagnantCount})',
                  fg: AppColors.warningColor(context),
                  bg: AppColors.surfaceColor(context),
                  onTap: onTapSignal != null
                      ? () => onTapSignal!('stagnant')
                      : null,
                ),
              if (summary.conflictCount > 0)
                _AttentionPill(
                  label: 'Jadwal Bentrok (${summary.conflictCount})',
                  fg: AppColors.expenseColor(context),
                  bg: AppColors.surfaceColor(context),
                  onTap: onTapSignal != null
                      ? () => onTapSignal!('conflict')
                      : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttentionPill extends StatelessWidget {
  final String label;
  final Color fg;
  final Color bg;
  final VoidCallback? onTap;

  const _AttentionPill({
    required this.label,
    required this.fg,
    required this.bg,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.35), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
    if (onTap == null) return pill;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: AppTokens.minTouchTarget,
            minHeight: AppTokens.minTouchTarget,
          ),
          child: Center(widthFactor: 1, child: pill),
        ),
      ),
    );
  }
}
