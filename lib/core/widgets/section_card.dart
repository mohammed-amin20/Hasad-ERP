import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../config/app_config.dart';
import '../theme/app_colors.dart';
import 'hasad_card.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.accent,
    this.trailing,
    this.footer,
    this.padding,
    this.scrollable = false,
    this.bodySpacing = AppConfig.cardGap,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final FaIconData? icon;
  final Color? iconColor;
  final Color? accent;
  final Widget? trailing;
  final Widget? footer;
  final EdgeInsetsGeometry? padding;
  final bool scrollable;
  final double bodySpacing;

  @override
  Widget build(BuildContext context) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        CardHeader(
          title: title,
          subtitle: subtitle,
          icon: icon,
          iconColor: iconColor,
          trailing: trailing,
        ),
        SizedBox(height: bodySpacing),
        child,
        if (footer != null) ...[
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          footer!,
        ],
      ],
    );

    return HasadCard(
      padding: padding ?? const EdgeInsets.all(AppConfig.cardPadding),
      accent: accent,
      child: scrollable
          ? ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: SingleChildScrollView(child: body),
            )
          : body,
    );
  }
}

class MetricRow extends StatelessWidget {
  const MetricRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasized = false,
    this.dense = false,
    this.leading,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasized;
  final bool dense;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 5 : 7),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: emphasized
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: valueColor ?? AppColors.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
