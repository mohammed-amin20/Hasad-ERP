import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'content_placeholder.dart';

/// Uniform page header + body shell for every screen in the app.
///
/// - Header: page title + optional subtitle, with optional trailing actions.
/// - Body: [child], or a [ContentPlaceholder] when null.
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.child,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.apps,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.headlineMedium),
                      if (subtitle != null)
                        Text(subtitle!, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                if (actions != null) ...[
                  const SizedBox(width: 12),
                  ...actions!,
                ],
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: child ?? const ContentPlaceholder(),
            ),
          ],
        ),
      ),
    );
  }
}