import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/content_placeholder.dart';
import '../../../core/widgets/page_scaffold.dart';

class ChartOfAccountsScreen extends StatelessWidget {
  const ChartOfAccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageScaffold(
      title: 'دليل الحسابات',
      subtitle: 'شجرة الحسابات المحاسبية',
      child: ContentPlaceholder(icon: FontAwesomeIcons.listOl),
    );
  }
}