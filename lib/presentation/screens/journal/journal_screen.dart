import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/content_placeholder.dart';
import '../../../core/widgets/page_scaffold.dart';

class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageScaffold(
      title: 'قيد اليومية',
      subtitle: 'القيود المحاسبية الآلية واليدوية',
      child: ContentPlaceholder(icon: FontAwesomeIcons.book),
    );
  }
}