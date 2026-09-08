import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/theme/app_theme.dart';
import 'package:hasad_erp/domain/auth/app_role.dart';
import 'package:hasad_erp/domain/auth/app_user.dart';
import 'package:hasad_erp/presentation/providers/auth_providers.dart';
import 'package:hasad_erp/presentation/shell/app_shell.dart';

/// Guards the redesign shell (sidebar + dashboard topbar cards) against
/// runtime layout exceptions without a Supabase connection.
void main() {
  testWidgets('shell and dashboard render without layout exceptions',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const user = AppUser(
      id: 'u1',
      email: 'admin@test.local',
      name: 'مدير النظام',
      role: AppRole.admin,
      tenantId: 't1',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(user)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const AppShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('لوحة التحكم'), findsWidgets);
    expect(find.text('المبيعات والعملاء'), findsOneWidget);
    expect(find.text('المحاسبة الأساسية'), findsOneWidget);

    final navList = find
        .ancestor(
          of: find.text('المبيعات والعملاء'),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('المالية والإدارة'),
      80,
      scrollable: navList,
    );
    expect(find.text('المالية والإدارة'), findsOneWidget);

    expect(find.text('مبيعات اليوم'), findsOneWidget);
    expect(find.text('ديون الموردين'), findsOneWidget);
    expect(find.text('مدير النظام'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shell and dashboard render on a narrow phone viewport',
      (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const user = AppUser(
      id: 'u1',
      email: 'admin@test.local',
      name: 'مدير النظام',
      role: AppRole.admin,
      tenantId: 't1',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(user)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const AppShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مبيعات اليوم'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}