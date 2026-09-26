import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'page_chrome.dart';

class RouteHeader extends StatelessWidget {
  const RouteHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.onClose,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final FaIconData? icon;
  final VoidCallback? onClose;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return PageChrome(
      title: title,
      subtitle: subtitle,
      icon: icon,
      actions: [
        ...actions,
        if (onClose != null)
          IconButton(
            onPressed: onClose,
            tooltip: 'إغلاق',
            icon: const FaIcon(FontAwesomeIcons.xmark, size: 18),
          ),
      ],
    );
  }
}
