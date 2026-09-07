import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/content_placeholder.dart';
import '../../../core/widgets/page_scaffold.dart';

class DebtsScreen extends StatelessWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageScaffold(
      title: 'الذمم والاستحقاقات',
      subtitle: 'ما لنا وما علينا مع تفاصيل الفواتير وكشوف الحساب',
      child: ContentPlaceholder(icon: FontAwesomeIcons.scaleBalanced),
    );
  }
}