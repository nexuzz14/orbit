import 'package:flutter/material.dart';
import 'package:orbit_app/core/constants/app_colors.dart';

export 'orbit_attention_card.dart';
export 'orbit_command_search.dart';
export 'orbit_formatters.dart';
export 'orbit_progress_control.dart';
export 'orbit_property_chip.dart';
export 'orbit_shell.dart';
export 'orbit_state_views.dart';
export 'orbit_status_badge.dart';
export 'orbit_view_switcher.dart';

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
    final card = Card(
      color: AppColors.surfaceColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        side: BorderSide(color: AppColors.borderColor(context)),
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
