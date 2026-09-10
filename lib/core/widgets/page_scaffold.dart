import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'content_placeholder.dart';
import 'user_corner.dart';

/// Uniform page header + body shell for every screen in the app.
///
/// - Header: a white rounded "topbar" card (matching the reference HTML)
///   with the page title + optional subtitle, optional trailing actions,
///   and the user corner (date + avatar).
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0D0F172A),
                    blurRadius: 6,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final showDate = constraints.maxWidth >= 700;
                  return Row(
                    children: [
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
                      if (actions != null)
                        for (final action in actions!) ...[
                          action,
                          const SizedBox(width: 4),
                        ],
                      if (actions != null && actions!.isNotEmpty)
                        const SizedBox(width: 8),
                      UserCorner(showDate: showDate),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Expanded(child: child ?? const ContentPlaceholder()),
          ],
        ),
      ),
    );
  }
}
