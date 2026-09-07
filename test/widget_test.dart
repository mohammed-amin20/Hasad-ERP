import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hasad_erp/core/theme/app_theme.dart';
import 'package:hasad_erp/domain/auth/app_role.dart';
import 'package:hasad_erp/domain/auth/app_user.dart';
import 'package:hasad_erp/domain/auth/auth_repository.dart';
import 'package:hasad_erp/presentation/providers/auth_providers.dart';
import 'package:hasad_erp/presentation/screens/auth/login_screen.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Stream<AppUser?> authStateChanges() => const Stream.empty();

  @override
  Future<AppUser?> signInWithPassword({
    required String email,
    required String password,
  }) async {
    return AppUser(
      id: 'u1',
      email: email,
      role: AppRole.admin,
      name: 'اختباري',
    );
  }

  @override
  Future<void> signOut() async {}
}

Widget _loginApp() {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
    ],
    child: MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      home: const LoginScreen(),
    ),
  );
}

void main() {
  testWidgets('login screen renders and validates the empty form',
      (tester) async {
    await tester.pumpWidget(_loginApp());

    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.text('حصاد'), findsWidgets);

    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pump();

    expect(find.text('أدخل البريد الإلكتروني'), findsOneWidget);
    expect(find.text('أدخل كلمة المرور'), findsOneWidget);
  });

  testWidgets('login screen submits valid credentials without error',
      (tester) async {
    await tester.pumpWidget(_loginApp());

    await tester.enterText(
        find.byType(TextFormField).at(0), 'owner@test.local');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret');
    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pumpAndSettle();

    // No validation or server error surfaced.
    expect(find.text('أدخل البريد الإلكتروني'), findsNothing);
    expect(find.text('أدخل كلمة المرور'), findsNothing);
    expect(find.byIcon(Icons.error_outline), findsNothing);
  });
}