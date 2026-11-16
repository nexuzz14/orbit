import 'package:flutter/material.dart';
import 'package:orbit_app/core/constants/app_colors.dart';

class OrbitKindBadge extends StatelessWidget {
  final String kind;

  const OrbitKindBadge({super.key, required this.kind});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = AppColors.getKindColor(kind, isDark: isDark);
    final bg = AppColors.getKindBgColor(kind, isDark: isDark);
    final border = AppColors.getKindBorderColor(kind, isDark: isDark);
    final label = AppColors.getKindLabel(kind);

    return Semantics(
      label: 'Jenis kegiatan $label',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space2,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppTokens.space1),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum OrbitBadgeVariant { neutral, income, expense, warning }

class OrbitStatusBadge extends StatelessWidget {
  final String label;
  final OrbitBadgeVariant variant;

  const OrbitStatusBadge({
    super.key,
    required this.label,
    this.variant = OrbitBadgeVariant.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    late final Color fg;
    late final Color bg;

    switch (variant) {
      case OrbitBadgeVariant.income:
        fg = isDark ? AppColors.incomeDark : AppColors.income;
        bg = isDark ? AppColors.incomeSubtleDark : AppColors.incomeSubtleLight;
        break;
      case OrbitBadgeVariant.expense:
        fg = isDark ? AppColors.expenseDark : AppColors.expense;
        bg = isDark ? AppColors.expenseSubtleDark : AppColors.expenseSubtleLight;
        break;
      case OrbitBadgeVariant.warning:
        fg = isDark ? AppColors.warningDark : AppColors.warning;
        bg = isDark ? AppColors.warningSubtleDark : AppColors.warningSubtleLight;
        break;
      case OrbitBadgeVariant.neutral:
        fg = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
        bg = isDark ? AppColors.darkSubtle : AppColors.lightSubtle;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
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
  }
}

class OrbitTaskStatusBadge extends StatelessWidget {
  final String status;
  final bool compact;

  const OrbitTaskStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = AppColors.getTaskStatusFg(status, isDark: isDark);
    final bg = AppColors.getTaskStatusBg(status, isDark: isDark);
    final border = AppColors.getTaskStatusBorder(status, isDark: isDark);
    final label = compact && status == 'todo'
        ? 'Belum'
        : AppColors.getTaskStatusLabel(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTokens.radiusXs),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppTokens.space1),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
