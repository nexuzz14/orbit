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
  final Color? borderColor;
  final Gradient? gradient;

  const OrbitCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTokens.space4),
    this.onTap,
    this.borderColor,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedBorder = borderColor ?? AppColors.borderColor(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTokens.radiusLg),
      side: BorderSide(color: resolvedBorder),
    );

    if (gradient != null) {
      return Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          border: Border.all(color: resolvedBorder),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          clipBehavior: Clip.antiAlias,
          child: onTap == null
              ? Padding(padding: padding, child: child)
              : InkWell(
                  borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                  onTap: onTap,
                  child: Padding(padding: padding, child: child),
                ),
        ),
      );
    }

    return Material(
      color: AppColors.surfaceColor(context),
      elevation: 1.5,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              borderRadius: BorderRadius.circular(AppTokens.radiusLg),
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
    );
  }
}
