import 'package:flutter/material.dart';
import 'package:orbit_app/core/constants/app_colors.dart';

class OrbitCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const OrbitCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTokens.space4),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = Card(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(AppTokens.radiusLg),
      onTap: onTap,
      child: card,
    );
  }
}

class OrbitKindBadge extends StatelessWidget {
  final String kind;

  const OrbitKindBadge({super.key, required this.kind});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = AppColors.getKindColor(kind, isDark: isDark);
    final bg = AppColors.getKindBgColor(kind, isDark: isDark);
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
          border: Border.all(color: fg.withValues(alpha: 0.3)),
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

class OrbitSkeleton extends StatelessWidget {
  final double height;
  final double? width;

  const OrbitSkeleton({
    super.key,
    this.height = 56,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: height,
      width: width ?? double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSubtle : AppColors.lightSubtle,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      ),
    );
  }
}

class OrbitEmptyState extends StatelessWidget {
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  const OrbitEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return OrbitCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space6,
        vertical: AppTokens.space6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 28,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
          const SizedBox(height: AppTokens.space2),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppTokens.space1),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppTokens.space4),
            FilledButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class OrbitErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const OrbitErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = AppColors.expenseColor(context);
    final bg = isDark ? AppColors.expenseSubtleDark : AppColors.expenseSubtleLight;

    return Container(
      padding: const EdgeInsets.all(AppTokens.space4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, size: 18, color: fg),
              const SizedBox(width: AppTokens.space2),
              Expanded(
                child: Text(
                  'Gagal Memuat Data',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space1),
          Text(
            message,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: AppTokens.space3),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Coba Lagi'),
            ),
          ),
        ],
      ),
    );
  }
}

String formatRupiah(double value, {String currency = 'IDR'}) {
  final intVal = value.round().abs();
  final digits = intVal.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    final posFromRight = digits.length - i;
    buffer.write(digits[i]);
    if (posFromRight > 1 && posFromRight % 3 == 1) {
      buffer.write('.');
    }
  }
  final prefix = currency == 'IDR' ? 'Rp' : '$currency ';
  return '$prefix$buffer';
}

String getGreeting({DateTime? dt, int offsetHours = 7}) {
  final localDt = (dt ?? DateTime.now()).toUtc().add(Duration(hours: offsetHours));
  final hour = localDt.hour;
  if (hour >= 4 && hour < 11) return 'Selamat Pagi';
  if (hour >= 11 && hour < 15) return 'Selamat Siang';
  if (hour >= 15 && hour < 18) return 'Selamat Sore';
  return 'Selamat Malam';
}

String formatTransactionGroupDateKey(String dateKey, {DateTime? now, int offsetHours = 7}) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
  ];
  const days = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];

  final parts = dateKey.split('-');
  if (parts.length != 3) return dateKey;
  final year = int.tryParse(parts[0]) ?? 1970;
  final month = int.tryParse(parts[1]) ?? 1;
  final day = int.tryParse(parts[2]) ?? 1;

  final ref = (now ?? DateTime.now()).toUtc().add(Duration(hours: offsetHours));
  final todayKey = '${ref.year.toString().padLeft(4, '0')}-${ref.month.toString().padLeft(2, '0')}-${ref.day.toString().padLeft(2, '0')}';
  final yesterday = ref.subtract(const Duration(days: 1));
  final yesterdayKey = '${yesterday.year.toString().padLeft(4, '0')}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

  if (dateKey == todayKey) return 'Hari ini';
  if (dateKey == yesterdayKey) return 'Kemarin';

  final targetDt = DateTime.utc(year, month, day);
  final dayName = days[targetDt.weekday % 7];
  final monthName = months[(month - 1).clamp(0, 11)];

  if (year != ref.year) {
    return '$dayName, $day $monthName $year';
  }
  return '$dayName, $day $monthName';
}

String formatTransactionGroupDate(DateTime date, {DateTime? now, int offsetHours = 7}) {
  final target = date.toUtc().add(Duration(hours: offsetHours));
  final key = '${target.year.toString().padLeft(4, '0')}-${target.month.toString().padLeft(2, '0')}-${target.day.toString().padLeft(2, '0')}';
  return formatTransactionGroupDateKey(key, now: now, offsetHours: offsetHours);
}

String formatDateIndoShort(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
  final dayName = days[(date.weekday - 1).clamp(0, 6)];
  final monthName = months[(date.month - 1).clamp(0, 11)];
  return '$dayName, ${date.day} $monthName ${date.year}';
}
