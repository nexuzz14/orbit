import 'package:flutter/material.dart';
import 'package:orbit_app/core/constants/app_colors.dart';

class OrbitPropertyChip extends StatelessWidget {
  final IconData? icon;
  final String label;
  final VoidCallback? onTap;
  final Color? foreground;
  final Color? background;
  final Color? borderColor;

  const OrbitPropertyChip({
    super.key,
    this.icon,
    required this.label,
    this.onTap,
    this.foreground,
    this.background,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? AppColors.textPrimaryColor(context);
    final bg = background ?? AppColors.subtleColor(context);
    final border = borderColor ?? AppColors.borderColor(context);

    final chip = Container(
      constraints: const BoxConstraints(minHeight: AppTokens.minTouchTarget),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space3,
        vertical: AppTokens.space2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: AppTokens.space1),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: fg,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return chip;
    return InkWell(
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      onTap: onTap,
      child: chip,
    );
  }
}

class OrbitPropertyRow extends StatelessWidget {
  final String label;
  final Widget value;

  const OrbitPropertyRow({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.space2),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderColor(context)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondaryColor(context),
              ),
            ),
          ),
          Expanded(child: value),
        ],
      ),
    );
  }
}

class OrbitBlockContainer extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const OrbitBlockContainer({
    super.key,
    this.title,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(AppTokens.space4),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceColor(context),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: AppColors.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null || trailing != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.space4,
                vertical: AppTokens.space2,
              ),
              decoration: BoxDecoration(
                color: AppColors.sidebarColor(context),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppTokens.radiusMd),
                ),
                border: Border(
                  bottom: BorderSide(color: AppColors.borderColor(context)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondaryColor(context),
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}
