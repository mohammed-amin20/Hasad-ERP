import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/content_placeholder.dart';
import '../../../core/widgets/page_scaffold.dart';

class SalariesScreen extends StatelessWidget {
  const SalariesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageScaffold(
      title: 'الرواتب',
      subtitle: 'الاستحقاقات والخصومات ودفع الرواتب',
      child: ContentPlaceholder(icon: FontAwesomeIcons.handHoldingDollar),
    );
  }
}