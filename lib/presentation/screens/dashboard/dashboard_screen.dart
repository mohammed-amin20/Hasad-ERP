import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/content_placeholder.dart';
import '../../../core/widgets/page_scaffold.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageScaffold(
      title: 'لوحة التحكم',
      subtitle: 'نظرة عامة على المبيعات والمخزون والذمم',
      child: ContentPlaceholder(icon: FontAwesomeIcons.gaugeHigh),
    );
  }
}