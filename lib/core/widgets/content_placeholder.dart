import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Friendly empty-state placeholder for screens not yet implemented.
class ContentPlaceholder extends StatelessWidget {
  const ContentPlaceholder({
    super.key,
    this.title = 'قريباً',
    this.message = 'هذه الشاشة ضمن خطة التطبيق وسيتم تفعيلها في المراحل القادمة',
    this.icon,
  });

  final String title;
  final String message;
  final FaIconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              FaIcon(
                icon,
                size: 48,
                color: AppColors.textMuted,
              )
            else
              Icon(
                Icons.construction_outlined,
                size: 48,
                color: AppColors.textMuted,
              ),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}