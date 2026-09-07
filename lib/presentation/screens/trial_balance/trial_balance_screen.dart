import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/content_placeholder.dart';
import '../../../core/widgets/page_scaffold.dart';

class TrialBalanceScreen extends StatelessWidget {
  const TrialBalanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageScaffold(
      title: 'ميزان المراجعة',
      subtitle: 'مطابقة المدين والدائن',
      child: ContentPlaceholder(icon: FontAwesomeIcons.scaleUnbalanced),
    );
  }
}