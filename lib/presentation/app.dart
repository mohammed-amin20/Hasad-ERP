import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../data/offline/local_store.dart';
import '../domain/auth/app_user.dart';
import 'providers/auth_providers.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'shell/app_shell.dart';
import 'widgets/no_workspace_view.dart';

/// Root widget: chooses Splash / Login / Shell from the auth stream.
class HasadApp extends ConsumerWidget {
  const HasadApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final store = ref.watch(localStoreProvider);

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
        builder: (context, child) {
          final reduceMotion =
              MediaQuery.maybeOf(context)?.disableAnimations ?? false;
          if (!reduceMotion) return child!;
          return Theme(data: AppTheme.lightReduced, child: child!);
        },
        home: _home(auth, store),
      ),
    );
  }

  /// Resolves the first screen.
  ///
  /// The local store is gated on **before** anything else is built. Every
  /// offline-first repository reads `ref.watch(localStoreProvider).value`,
  /// which is null while the database is still opening, and a null store makes
  /// `cacheFirst` / `cacheLast` (`data/offline/offline_reads.dart`) skip the
  /// local mirror entirely — so an offline cold start would show "no data"
  /// while the data sat in SQLite. Gating once here means every wrapper sees a
  /// real store, instead of threading `.future` through eleven providers.
  ///
  /// Note `authStateProvider` already awaits the store transitively (it
  /// resolves `authRepositoryProvider`, which opens it), so this gate is
  /// currently redundant with the `auth.when(loading:)` branch below. It is
  /// kept explicit on purpose: the shell is the thing that must never be built
  /// without a store, and a future refactor of `authStateProvider` should not
  /// be able to silently reintroduce the bug.
  Widget _home(AsyncValue<AppUser?> auth, AsyncValue<LocalStore> store) {
    if (store.isLoading) return const SplashScreen();
    return auth.when(
      loading: () => const SplashScreen(),
      // Reached only for a genuine auth failure (revoked/expired session) or
      // an unreadable profile. Offline never gets here: the auth decorator
      // serves the cached profile and completes its stream normally instead of
      // forwarding a NetworkException.
      error: (_, _) => const LoginScreen(),
      data: (user) => user == null
          ? const LoginScreen()
          : user.hasTenant
              ? const AppShell()
              : const NoWorkspaceView(),
    );
  }
}
