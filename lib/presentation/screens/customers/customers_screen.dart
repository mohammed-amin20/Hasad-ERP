import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/content_placeholder.dart';
import '../../../core/widgets/page_scaffold.dart';

class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageScaffold(
      title: 'العملاء',
      subtitle: 'إدارة بيانات العملاء وحساباتهم',
      child: ContentPlaceholder(icon: FontAwesomeIcons.users),
    );
  }
}