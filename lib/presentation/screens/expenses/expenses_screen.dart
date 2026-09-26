import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../widgets/state_views.dart';

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'المصاريف',
      subtitle: 'تسجيل مصاريف المنشأة',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppConfig.maxContentWidth),
          child: const EmptyStateCard(
            icon: FontAwesomeIcons.moneyBillWave,
            title: 'مصاريف المنشأة',
            message:
                'ستتيح هذه الشاشة تسجيل بنود المصاريف وربطها بالقيود المحاسبية، '
                'وهي ضمن خطة التطوير القادمة.',
          ),
        ),
      ),
    );
  }
}
