import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../config/app_config.dart';
import '../theme/app_colors.dart';
import 'hasad_card.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueColor,
    this.accentColor,
    this.backgroundColor,
    this.borderColor,
    this.caption,
    this.captionIcon,
    this.captionColor,
    this.onTap,
  });

  final FaIconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color? valueColor;
  final Color? accentColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final String? caption;
  final FaIconData? captionIcon;
  final Color? captionColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InteractiveCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppConfig.cardPadding),
      accent: accentColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconChip(
                icon: icon,
                color: iconColor,
                size: 32,
                iconSize: 15,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.displayLarge?.copyWith(
                color: valueColor ?? AppColors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (caption != null && caption!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (captionIcon != null) ...[
                  FaIcon(
                    captionIcon,
                    size: 11,
                    color: captionColor ?? AppColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    caption!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: captionColor ?? AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Responsive KPI grid: 4 columns on wide desktops, 2 on tablets, 1 on
/// narrow phones. The shared rhythm for every list of metrics in the app.
class StatCardGrid extends StatelessWidget {
  const StatCardGrid({super.key, required this.cards, this.extent = 148});

  final List<Widget> cards;
  final double extent;

  static int columnsFor(double width) {
    if (width >= 1040) return 4;
    if (width >= 440) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnsFor(constraints.maxWidth),
            mainAxisSpacing: AppConfig.cardGap,
            crossAxisSpacing: AppConfig.cardGap,
            mainAxisExtent: extent,
          ),
          children: cards,
        );
      },
    );
  }
}
