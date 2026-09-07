import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/content_placeholder.dart';
import '../../../core/widgets/page_scaffold.dart';

class FinancialStatementsScreen extends StatelessWidget {
  const FinancialStatementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageScaffold(
      title: 'القوائم المالية',
      subtitle: 'قائمة الدخل والميزانية العمومية',
      child: ContentPlaceholder(icon: FontAwesomeIcons.chartColumn),
    );
  }
}