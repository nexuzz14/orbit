import 'package:flutter/material.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/widgets/orbit_widgets.dart';

class ScheduleEventCard extends StatelessWidget {
  final LocalEvent event;
  final bool hasConflict;
  final Color secondaryColor;
  final VoidCallback onDelete;

  const ScheduleEventCard({
    super.key,
    required this.event,
    required this.hasConflict,
    required this.secondaryColor,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final kindColor = AppColors.getKindColor(event.kind, isDark: isDark);
    final startStr =
        '${event.startsAt.hour.toString().padLeft(2, '0')}:${event.startsAt.minute.toString().padLeft(2, '0')}';
    final endStr =
        '${event.endsAt.hour.toString().padLeft(2, '0')}:${event.endsAt.minute.toString().padLeft(2, '0')}';

    return OrbitCard(
      padding: const EdgeInsets.all(AppTokens.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 52,
            decoration: BoxDecoration(
              color: kindColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppTokens.space3),
          SizedBox(
            width: 84,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$startStr - $endStr',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatDateIndoShort(event.startsAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: secondaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (event.location != null && event.location!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    event.location!,
                    style: TextStyle(fontSize: 12, color: secondaryColor),
                  ),
                ],
                const SizedBox(height: AppTokens.space2),
                Wrap(
                  spacing: AppTokens.space2,
                  runSpacing: AppTokens.space1,
                  children: [
                    OrbitKindBadge(kind: event.kind),
                    if (hasConflict)
                      const OrbitStatusBadge(
                        label: 'Bentrok Waktu',
                        variant: OrbitBadgeVariant.warning,
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            tooltip: 'Hapus Jadwal',
            constraints: const BoxConstraints(
              minWidth: AppTokens.minTouchTarget,
              minHeight: AppTokens.minTouchTarget,
            ),
            icon: const Icon(Icons.delete_outline, size: 18),
          ),
        ],
      ),
    );
  }
}
