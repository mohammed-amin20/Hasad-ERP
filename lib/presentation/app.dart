import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import 'providers/auth_providers.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'shell/app_shell.dart';

/// Root widget: chooses Splash / Login / Shell from the auth stream.
class HasadApp extends ConsumerWidget {
  const HasadApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: MaterialApp(
        title: 'حصاد',
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: auth.when(
          loading: () => const SplashScreen(),
          error: (_, _) => const LoginScreen(),
          data: (user) => user == null ? const LoginScreen() : const AppShell(),
        ),
      ),
    );
  }
}