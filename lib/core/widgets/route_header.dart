import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Floating white header card for full-screen routes (replaces the legacy
/// Material `AppBar`). Matches the `PageScaffold` topbar visual language:
/// white surface, 16px radius, hairline border, soft shadow, Cairo title.
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
    return Container(
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
      child: Row(
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
  }
}