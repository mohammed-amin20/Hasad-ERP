import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/content_placeholder.dart';
import '../../../core/widgets/page_scaffold.dart';

class LedgerScreen extends StatelessWidget {
  const LedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageScaffold(
      title: 'الأستاذ العام',
      subtitle: 'أرصدة الحسابات الجارية',
      child: ContentPlaceholder(icon: FontAwesomeIcons.bookOpen),
    );
  }
}