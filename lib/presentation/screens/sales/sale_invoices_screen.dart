import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/content_placeholder.dart';
import '../../../core/widgets/page_scaffold.dart';

class SaleInvoicesScreen extends StatelessWidget {
  const SaleInvoicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageScaffold(
      title: 'المبيعات',
      subtitle: 'إنشاء ومتابعة فواتير البيع',
      child: ContentPlaceholder(icon: FontAwesomeIcons.basketShopping),
    );
  }
}