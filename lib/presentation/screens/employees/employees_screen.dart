import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/content_placeholder.dart';
import '../../../core/widgets/page_scaffold.dart';

class EmployeesScreen extends StatelessWidget {
  const EmployeesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageScaffold(
      title: 'الموظفون',
      subtitle: 'بيانات الموظفين والرواتب الأساسية',
      child: ContentPlaceholder(icon: FontAwesomeIcons.userTie),
    );
  }
}