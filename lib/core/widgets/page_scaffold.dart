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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        final outerPadding = isMobile ? 16.0 : 24.0;
        final headerVPadding = isMobile ? 10.0 : 14.0;
        final headerHPadding = isMobile ? 16.0 : 20.0;
        final headerRadius = isMobile ? 12.0 : 16.0;
        const gapAfterHeader = 16.0;

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.all(outerPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: headerHPadding,
                    vertical: headerVPadding,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(headerRadius),
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
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title,
                                  style: theme.textTheme.headlineMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (subtitle != null && !isMobile)
                                  Text(
                                    subtitle!,
                                    style: theme.textTheme.bodySmall,
                                  ),
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
                SizedBox(height: gapAfterHeader),
                Expanded(child: child ?? const ContentPlaceholder()),
              ],
            ),
          ),
        );
      },
    );
  }
}
