import 'package:flutter/material.dart';
import 'package:orbit_app/core/constants/app_colors.dart';

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
    return Container(
      height: height,
      width: width ?? double.infinity,
      decoration: BoxDecoration(
        color: AppColors.subtleColor(context),
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
    return Card(
      child: Padding(
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
              color: AppColors.textSecondaryColor(context),
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
                color: AppColors.textSecondaryColor(context),
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
