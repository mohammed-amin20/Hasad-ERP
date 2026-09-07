import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/content_placeholder.dart';
import '../../../core/widgets/page_scaffold.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageScaffold(
      title: 'الإعدادات',
      subtitle: 'إعدادات المنشأة والتذكيرات والنسخ الاحتياطي',
      child: ContentPlaceholder(icon: FontAwesomeIcons.gear),
    );
  }
}