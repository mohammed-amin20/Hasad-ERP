import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Dashboard stat card replicating the HTML `.stat-card`: white surface,
/// 16px radius, hairline border, soft shadow, a labeled icon row and a bold
/// value. Optional right accent bar and tinted fills for highlighted cards.
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
  });

  final FaIconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color? valueColor;

  /// Colored 4px accent on the right edge (HTML `border-right: 4px solid`).
  final Color? accentColor;

  /// Optional tinted fill (e.g. the green profit card).
  final Color? backgroundColor;

  /// Optional border override (e.g. green-200 on the profit card).
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? AppColors.border, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    FaIcon(icon, size: 16, color: iconColor),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    letterSpacing: -0.5,
                    color: valueColor ?? AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (accent != null)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 4, color: accent),
            ),
        ],
      ),
    );
  }
}