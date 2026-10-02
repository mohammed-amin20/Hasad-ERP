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
import 'widgets/local_data_repair_screen.dart';
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
  /// A store *error* is not the login screen: `openLocalStore` fails loudly
  /// (`LocalStoreOpenException`) when the database cannot open or migrate, and
  /// that renders the Arabic repair state — Retry, plus an explicit destructive
  /// "Reset local data" the user must confirm. Signing out is never reached
  /// from here, and neither is a silent empty shell.
  Widget _home(AsyncValue<AppUser?> auth, AsyncValue<LocalStore> store) {
    // A failed FutureProvider surfaces as AsyncLoading-with-error in this
    // Riverpod (3.4.3): `when(error:)` is never called for it, so the gate
    // must branch on `hasError` explicitly or the failure would render as an
    // endless splash.
    if (store.hasError) {
      return LocalDataRepairScreen(error: store.error!);
    }
    if (!store.hasValue) return const SplashScreen();
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
