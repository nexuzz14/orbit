import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/services/privacy_and_lock_service.dart';
import 'package:orbit_app/core/widgets/orbit_privacy_widgets.dart';
import 'package:orbit_app/core/widgets/orbit_widgets.dart';

class TodaySectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? countLabel;

  const TodaySectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.countLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: AppTokens.space2),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        if (countLabel != null) OrbitStatusBadge(label: countLabel!),
      ],
    );
  }
}

class TodayAlertBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDanger;

  const TodayAlertBanner({
    super.key,
    required this.icon,
    required this.text,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final fg = isDanger
        ? AppColors.expenseColor(context)
        : AppColors.warningColor(context);
    final bg = isDanger
        ? (isDark ? AppColors.expenseSubtleDark : AppColors.expenseSubtleLight)
        : (isDark ? AppColors.warningSubtleDark : AppColors.warningSubtleLight);

    return Container(
      padding: const EdgeInsets.all(AppTokens.space3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: AppTokens.space2),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TodayEventRow extends StatelessWidget {
  final Map<String, dynamic> event;
  final bool hasConflict;
  final VoidCallback? onTap;

  const TodayEventRow({
    super.key,
    required this.event,
    this.hasConflict = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final startsAt = event['starts_at'] as DateTime;
    final endsAt = event['ends_at'] as DateTime;
    final timeStr = event['all_day'] == true
        ? 'Seharian'
        : '${DateFormat('HH:mm').format(startsAt)} - ${DateFormat('HH:mm').format(endsAt)}';
    final kind = event['kind'] as String? ?? 'pribadi';
    final location = event['location'] as String?;

    final content = Padding(
      padding: const EdgeInsets.all(AppTokens.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              timeStr,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryColor(context),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: AppTokens.space2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event['title'] as String? ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTokens.space1),
                Wrap(
                  spacing: AppTokens.space2,
                  runSpacing: AppTokens.space1,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OrbitKindBadge(kind: kind),
                    if (hasConflict)
                      const OrbitStatusBadge(
                        label: 'Benturan',
                        variant: OrbitBadgeVariant.expense,
                      ),
                    if (location != null && location.isNotEmpty)
                      Text(
                        location,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryColor(context),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.more_horiz_rounded,
              size: 18,
              color: AppColors.textMutedColor(context),
            ),
        ],
      ),
    );

    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

class TodayTaskRow extends StatelessWidget {
  final Map<String, dynamic> task;
  final VoidCallback onToggleStatus;
  final VoidCallback? onTap;
  final VoidCallback? onFocusTap;
  final VoidCallback? onScheduleTap;
  final VoidCallback? onExpenseTap;

  const TodayTaskRow({
    super.key,
    required this.task,
    required this.onToggleStatus,
    this.onTap,
    this.onFocusTap,
    this.onScheduleTap,
    this.onExpenseTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = task['status'] as String? ?? 'todo';
    final isDone = status == 'done' || status == 'selesai';
    final isOverdue = task['is_overdue'] == true;
    final kind = task['kind'] as String? ?? 'pribadi';
    final priority = task['priority'] as String? ?? 'sedang';
    final progress = (task['progress_percent'] as num?)?.toInt() ?? 0;
    final revisionCount = (task['revision_count'] as num?)?.toInt() ?? 0;
    final isStagnant = task['is_stagnant'] == true;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space2,
          vertical: AppTokens.space2,
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: onToggleStatus,
              tooltip: isDone ? 'Tandai belum selesai' : 'Tandai selesai',
              constraints: const BoxConstraints(
                minWidth: AppTokens.minTouchTarget,
                minHeight: AppTokens.minTouchTarget,
              ),
              icon: Icon(
                isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isDone
                    ? AppColors.incomeColor(context)
                    : Theme.of(context).colorScheme.outline,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task['title'] as String? ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: AppTokens.space1),
                  Wrap(
                    spacing: AppTokens.space2,
                    runSpacing: AppTokens.space1,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OrbitTaskStatusBadge(status: status, compact: true),
                      OrbitKindBadge(kind: kind),
                      Text(
                        '$progress%',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondaryColor(context),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (revisionCount > 0)
                        OrbitStatusBadge(
                          label: 'Revisi $revisionCount kali',
                          variant: OrbitBadgeVariant.warning,
                        ),
                      if (isStagnant)
                        const OrbitStatusBadge(
                          label: 'Macet >5 hari',
                          variant: OrbitBadgeVariant.warning,
                        ),
                      if (isOverdue && !isDone)
                        const OrbitStatusBadge(
                          label: 'Terlambat',
                          variant: OrbitBadgeVariant.expense,
                        ),
                      if (priority == 'tinggi' || priority == 'mendesak')
                        const OrbitStatusBadge(
                          label: 'Prioritas Tinggi',
                          variant: OrbitBadgeVariant.warning,
                        ),
                    ],
                  ),
                  if (!isDone &&
                      (onFocusTap != null ||
                          onScheduleTap != null ||
                          onExpenseTap != null)) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (onFocusTap != null)
                          _TaskInlineActionPill(
                            icon: Icons.timer_outlined,
                            label: 'Fokus',
                            onTap: onFocusTap!,
                          ),
                        if (onScheduleTap != null)
                          _TaskInlineActionPill(
                            icon: Icons.event_available_outlined,
                            label: 'Jadwalkan',
                            onTap: onScheduleTap!,
                          ),
                        if (onExpenseTap != null)
                          _TaskInlineActionPill(
                            icon: Icons.receipt_long_outlined,
                            label: 'Biaya',
                            onTap: onExpenseTap!,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textMutedColor(context),
              ),
          ],
        ),
      ),
    );
  }
}

class TodayMoneySummaryCard extends StatelessWidget {
  final double liquidBalance;
  final double todayIncome;
  final double todayExpense;
  final int draftCount;
  final VoidCallback onOpenInbox;
  final VoidCallback onQuickAdd;

  const TodayMoneySummaryCard({
    super.key,
    required this.liquidBalance,
    required this.todayIncome,
    required this.todayExpense,
    required this.draftCount,
    required this.onOpenInbox,
    required this.onQuickAdd,
  });

  @override
  Widget build(BuildContext context) {
    return OrbitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Total Saldo Likuid',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondaryColor(context),
            ),
          ),
          const SizedBox(height: AppTokens.space1),
          OrbitAmountText(
            amount: liquidBalance,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: AppTokens.space4),
          OrbitPrivacyBuilder(
            builder: (context, _) => Row(
              children: [
                Expanded(
                  child: _TodayStatTile(
                    label: 'Pemasukan Hari Ini',
                    value: PrivacyModeController.instance.enabled
                        ? PrivacyModeController.maskedPlaceholder
                        : '+${formatRupiah(todayIncome)}',
                    valueColor: AppColors.incomeColor(context),
                  ),
                ),
                const SizedBox(width: AppTokens.space3),
                Expanded(
                  child: _TodayStatTile(
                    label: 'Pengeluaran Hari Ini',
                    value: PrivacyModeController.instance.enabled
                        ? PrivacyModeController.maskedPlaceholder
                        : '-${formatRupiah(todayExpense)}',
                    valueColor: AppColors.expenseColor(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space3),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenInbox,
                  icon: const Icon(Icons.inbox_outlined, size: 18),
                  label: Text('Inbox ($draftCount Draft)'),
                ),
              ),
              const SizedBox(width: AppTokens.space2),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onQuickAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Catat Uang'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodayStatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _TodayStatTile({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.space3),
      decoration: BoxDecoration(
        color: AppColors.subtleColor(context),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondaryColor(context),
            ),
          ),
          const SizedBox(height: AppTokens.space1),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: valueColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskInlineActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _TaskInlineActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentColor(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.subtleColor(context),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.borderColor(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: accent),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimaryColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
