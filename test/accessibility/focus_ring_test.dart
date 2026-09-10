import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/theme/app_colors.dart';
import 'package:hasad_erp/core/theme/app_theme.dart';

void main() {
  final theme = AppTheme.light;

  Widget wrap(Widget child) => MaterialApp(
        theme: theme,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: Center(child: child)),
        ),
      );

  ThemeData themeOf(WidgetTester tester, Type buttonType) =>
      Theme.of(tester.element(find.byType(buttonType).first));

  testWidgets('theme defines hover/focus overlay colors', (tester) async {
    await tester.pumpWidget(wrap(const Text('x')));
    final data = Theme.of(tester.element(find.byType(Text).first));

    expect(data.hoverColor, AppColors.primary.withValues(alpha: 0.08));
    expect(data.focusColor, AppColors.primary.withValues(alpha: 0.12));
  });

  testWidgets('elevated button shows a 2px primary focus ring when focused',
      (tester) async {
    await tester.pumpWidget(
      wrap(ElevatedButton(onPressed: () {}, child: const Text('b'))),
    );
    final shape = themeOf(tester, ElevatedButton).elevatedButtonTheme.style!
        .shape!.resolve({WidgetState.focused})! as RoundedRectangleBorder;
    expect(shape.side.width, 2);
    expect(shape.side.color, AppColors.primary);
  });

  testWidgets('text button shows a 2px primary focus ring when focused',
      (tester) async {
    await tester.pumpWidget(
      wrap(TextButton(onPressed: () {}, child: const Text('b'))),
    );
    final shape = themeOf(tester, TextButton).textButtonTheme.style!.shape!
        .resolve({WidgetState.focused})! as RoundedRectangleBorder;
    expect(shape.side.width, 2);
    expect(shape.side.color, AppColors.primary);
  });

  testWidgets('outlined button thickens to a 2px border when focused',
      (tester) async {
    await tester.pumpWidget(
      wrap(OutlinedButton(onPressed: () {}, child: const Text('b'))),
    );
    final side = themeOf(tester, OutlinedButton).outlinedButtonTheme.style!
        .side!.resolve({WidgetState.focused})!;
    expect(side.width, 2);
    expect(side.color, AppColors.primaryDark);
  });

  testWidgets('icon buttons keep a 48x48 minimum touch target',
      (tester) async {
    await tester.pumpWidget(
      wrap(IconButton(onPressed: () {}, icon: const Icon(Icons.add))),
    );
    final size = themeOf(tester, IconButton).iconButtonTheme.style!
        .minimumSize!.resolve({});
    expect(size, const Size(48, 48));
  });
}