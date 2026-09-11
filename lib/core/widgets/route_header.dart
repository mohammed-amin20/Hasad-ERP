import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Floating white header card for full-screen routes (replaces the legacy
/// Material `AppBar`). Matches the `PageScaffold` topbar visual language:
/// white surface, responsive radius, hairline border, soft shadow, Cairo title.
class RouteHeader extends StatelessWidget {
  const RouteHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onClose,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onClose;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        final hPadding = isMobile ? 16.0 : 20.0;
        final vPadding = isMobile ? 10.0 : 14.0;
        final radius = isMobile ? 12.0 : 16.0;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: vPadding),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D0F172A),
                blurRadius: 6,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.headlineMedium,
                      maxLines: isMobile ? 1 : null,
                      overflow: isMobile ? TextOverflow.ellipsis : null,
                    ),
                    if (subtitle != null && !isMobile)
                      Text(subtitle!, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              for (final action in actions) ...[action, const SizedBox(width: 4)],
              if (actions.isNotEmpty) const SizedBox(width: 8),
              if (onClose != null)
                IconButton(
                  onPressed: onClose,
                  tooltip: 'إغلاق',
                  icon: const FaIcon(FontAwesomeIcons.xmark, size: 18),
                ),
            ],
          ),
        );
      },
    );
  }
}
