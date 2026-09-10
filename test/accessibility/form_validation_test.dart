import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hasad_erp/core/theme/app_colors.dart';
import 'package:hasad_erp/core/theme/app_theme.dart';
import 'package:hasad_erp/core/utils/money.dart';
import 'package:hasad_erp/presentation/widgets/invoice_input_fields.dart';

Widget _harness(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: child),
);

void main() {
  group('inline error styling (W8-4)', () {
    test('error text renders in danger color at 12sp, two lines max', () {
      final theme = AppTheme.light;
      final style = theme.inputDecorationTheme.errorStyle;
      expect(style, isNotNull);
      expect(style!.color, AppColors.danger);
      expect(style.fontSize, 12);
      expect(theme.inputDecorationTheme.errorMaxLines, 2);
    });

    test('error borders use danger, thickened to 2px when focused', () {
      final theme = AppTheme.light;
      final focused =
          theme.inputDecorationTheme.focusedErrorBorder as OutlineInputBorder;
      expect(focused.borderSide.color, AppColors.danger);
      expect(focused.borderSide.width, 2);
      final border =
          theme.inputDecorationTheme.errorBorder as OutlineInputBorder;
      expect(border.borderSide.color, AppColors.danger);
    });
  });

  group('onUserInteraction inline validation (W8-4)', () {
    testWidgets('errors appear as the user types and clear when fixed', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          Form(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: TextFormField(
              decoration: const InputDecoration(labelText: 'العميل'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'أدخل اسم العميل' : null,
            ),
          ),
        ),
      );

      expect(find.text('أدخل اسم العميل'), findsNothing);

      await tester.enterText(find.byType(TextFormField), 'أ');
      await tester.pump();
      expect(find.text('أدخل اسم العميل'), findsNothing);

      await tester.enterText(find.byType(TextFormField), '');
      await tester.pump();
      expect(find.text('أدخل اسم العميل'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'أحمد');
      await tester.pump();
      expect(find.text('أدخل اسم العميل'), findsNothing);
    });

    testWidgets('PriceField reports required and format errors inline', (
      tester,
    ) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        _harness(
          Form(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: PriceField(
              controller: controller,
              label: 'المبلغ',
              requiredMessage: 'أدخل مبلغاً صحيحاً',
            ),
          ),
        ),
      );
      final field = find.byType(TextFormField);

      await tester.enterText(field, '1');
      await tester.pump();
      expect(find.text('أدخل مبلغاً صحيحاً'), findsNothing);

      await tester.enterText(field, '');
      await tester.pump();
      expect(find.text('أدخل مبلغاً صحيحاً'), findsOneWidget);

      await tester.enterText(field, 'abc');
      await tester.pump();
      expect(find.text('قيمة غير صالحة'), findsOneWidget);

      await tester.enterText(field, '150');
      await tester.pump();
      expect(find.text('أدخل مبلغاً صحيحاً'), findsNothing);
      expect(find.text('قيمة غير صالحة'), findsNothing);
    });

    testWidgets('PriceField extraValidator enforces business ranges inline', (
      tester,
    ) async {
      final controller = TextEditingController(text: '1500');
      await tester.pumpWidget(
        _harness(
          Form(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: PriceField(
              controller: controller,
              label: 'المبلغ',
              requiredMessage: 'أدخل مبلغ دفع صحيحاً',
              extraValidator: (v) {
                final amount = priceToAgorot(v ?? '');
                if (amount == null || amount <= 0) {
                  return 'أدخل مبلغ دفع صحيحاً';
                }
                if (amount > Money.fromAmount(2000)) {
                  return 'المبلغ أكبر من المتبقي على الفاتورة';
                }
                return null;
              },
            ),
          ),
        ),
      );
      final field = find.byType(TextFormField);

      await tester.enterText(field, '3000');
      await tester.pump();
      expect(find.text('المبلغ أكبر من المتبقي على الفاتورة'), findsOneWidget);

      await tester.enterText(field, '1500');
      await tester.pump();
      expect(find.text('المبلغ أكبر من المتبقي على الفاتورة'), findsNothing);
    });
  });
}
