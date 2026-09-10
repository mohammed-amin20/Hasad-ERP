import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/content_placeholder.dart';
import '../../../core/widgets/page_scaffold.dart';

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageScaffold(
      title: 'المصاريف',
      subtitle: 'تسجيل مصاريف المنشأة',
      child: ContentPlaceholder(icon: FontAwesomeIcons.moneyBillWave),
    );
  }
}
