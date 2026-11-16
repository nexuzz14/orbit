import 'package:flutter/material.dart';
import 'package:orbit_app/core/constants/app_colors.dart';

class OrbitProgressControl extends StatelessWidget {
  final int value;
  final bool lockedByChecklist;
  final ValueChanged<int>? onChanged;
  final bool compact;

  const OrbitProgressControl({
    super.key,
    required this.value,
    this.lockedByChecklist = false,
    this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0, 100);
    final fillColor = clamped >= 100
        ? AppColors.incomeColor(context)
        : clamped > 0
            ? AppColors.accentColor(context)
            : AppColors.textMutedColor(context);

    final bar = Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: clamped / 100.0,
              minHeight: compact ? 5 : 7,
              backgroundColor: AppColors.subtleColor(context),
              valueColor: AlwaysStoppedAnimation<Color>(fillColor),
            ),
          ),
        ),
        const SizedBox(width: AppTokens.space2),
        Text(
          '$clamped%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondaryColor(context),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (!compact && lockedByChecklist) ...[
          const SizedBox(width: AppTokens.space1),
          Icon(
            Icons.lock_outline,
            size: 13,
            color: AppColors.textMutedColor(context),
          ),
        ],
      ],
    );

    if (compact || lockedByChecklist || onChanged == null) {
      return bar;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        bar,
        Slider(
          value: clamped.toDouble(),
          min: 0,
          max: 100,
          divisions: 20,
          label: '$clamped%',
          onChanged: (next) => onChanged!((next / 5).round() * 5),
        ),
      ],
    );
  }
}
