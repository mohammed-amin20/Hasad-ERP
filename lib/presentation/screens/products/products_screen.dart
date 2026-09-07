import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/content_placeholder.dart';
import '../../../core/widgets/page_scaffold.dart';

class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageScaffold(
      title: 'المنتجات',
      subtitle: 'منتجات عدّادة ووزنية مع الأسعار والأرصدة',
      child: ContentPlaceholder(icon: FontAwesomeIcons.box),
    );
  }
}