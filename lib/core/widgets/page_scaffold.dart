import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../config/app_config.dart';
import '../theme/app_page_icons.dart';
import 'content_placeholder.dart';
import 'page_chrome.dart';
import 'user_corner.dart';

class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.actions,
    this.child,
    this.padded = true,
  });

  final String title;
  final String? subtitle;
  final FaIconData? icon;
  final Color? iconColor;
  final List<Widget>? actions;
  final Widget? child;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < AppConfig.breakpointNarrow;
        final outerPadding = padded
            ? (isMobile
                  ? AppConfig.pageGutterNarrow
                  : AppConfig.pageGutter)
            : 0.0;

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.all(outerPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageChrome(
                  title: title,
                  subtitle: subtitle,
                  icon: icon ?? AppPageIcons.of(title),
                  iconColor: iconColor,
                  actions: actions ?? const [],
                  trailing: isMobile ? null : const UserCorner(showDate: true),
                ),
                const SizedBox(height: AppConfig.sectionGap / 1.5),
                Expanded(child: child ?? const ContentPlaceholder()),
              ],
            ),
          ),
        );
      },
    );
  }
}