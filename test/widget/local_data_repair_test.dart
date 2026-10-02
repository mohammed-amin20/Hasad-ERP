import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/presentation/app.dart';
import 'package:hasad_erp/presentation/providers/auth_providers.dart';
import 'package:hasad_erp/presentation/screens/auth/login_screen.dart';
import 'package:hasad_erp/presentation/widgets/local_data_repair_screen.dart';

/// P0 issue 6 — the app gate must turn a failing store open into the Arabic
/// repair state instead of a silent empty shell (or a crash).
///
/// Covers the two sanctioned actions and their seams:
/// - «إعادة المحاولة» re-runs `localStoreProvider`; a transient failure that
///   clears on retry leaves the repair screen and the app continues.
/// - «إعادة تعيين البيانات المحلية» is DANGEROUS: it requires a confirmation
///   dialog (danger tone warn about unsynced data), cancel leaves everything
///   untouched, confirm invokes the injected `resetLocalDatabaseProvider` once
///   and re-opens the store gate.
void main() {
  late AppDatabase db;
  late LocalStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftLocalStore(db);
  });

  tearDown(() => db.close());

  // Riverpod 3.4.3 auto-retries a failed provider with exponential backoff;
  // with the default policy a counting storeFactory is re-invoked mid-settle
  // and the second call (which returns a store) flips the gate to the login
  // screen before the repair assertion runs. Production keeps that retry (a
  // transient one and a half-open file both recover on their own); the tests
  // disable it so a throwing factory behaves deterministically.
  void useDesktopSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Mounts the real [HasadApp] with a stubbed auth stream (null user) so the
  /// gate settles on the login screen once the store succeeds.
  Widget app({
    required Future<LocalStore> Function(Ref) storeFactory,
    Future<void> Function()? reset,
  }) {
    return ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        localStoreProvider.overrideWith(storeFactory),
        authStateProvider.overrideWith((ref) async* { yield null; }),
        if (reset != null) resetLocalDatabaseProvider.overrideWithValue(reset),
      ],
      child: const HasadApp(),
    );
  }

  testWidgets('store open failure renders the Arabic repair screen',
      (tester) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(app(
      storeFactory: (ref) async =>
          throw const LocalStoreOpenException('corrupt file: test'),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(LocalDataRepairScreen), findsOneWidget);
    expect(find.text('تعذر فتح البيانات المحلية'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    expect(find.text('إعادة تعيين البيانات المحلية'), findsOneWidget);
    // never a shell or login while the store is unreadable
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('retry re-runs the store open and leaves the repair screen',
      (tester) async {
    useDesktopSurface(tester);
    var opens = 0;
    await tester.pumpWidget(app(
      storeFactory: (ref) async {
        opens++;
        if (opens == 1) throw const LocalStoreOpenException('transient');
        return store;
      },
    ));
    await tester.pumpAndSettle();
    expect(find.byType(LocalDataRepairScreen), findsOneWidget);

    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();

    expect(opens, 2);
    expect(find.byType(LocalDataRepairScreen), findsNothing);
    // signed-out user lands on login once the store is healthy
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('reset demands confirmation; cancelling changes nothing',
      (tester) async {
    useDesktopSurface(tester);
    var resets = 0;
    await tester.pumpWidget(app(
      storeFactory: (ref) async =>
          throw const LocalStoreOpenException('corrupt file: test'),
      reset: () async => resets++,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('إعادة تعيين البيانات المحلية'));
    await tester.pumpAndSettle();

    expect(find.text('إعادة تعيين البيانات المحلية؟'), findsOneWidget);
    expect(find.text('إلغاء'), findsOneWidget);

    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    expect(resets, 0);
    expect(find.byType(LocalDataRepairScreen), findsOneWidget);
  });

  testWidgets('confirming reset wipes the file once and re-opens the store',
      (tester) async {
    useDesktopSurface(tester);
    var resets = 0;
    var opens = 0;
    await tester.pumpWidget(app(
      storeFactory: (ref) async {
        opens++;
        if (opens == 1) throw const LocalStoreOpenException('corrupt file');
        return store;
      },
      reset: () async => resets++,
    ));
    await tester.pumpAndSettle();
    expect(find.byType(LocalDataRepairScreen), findsOneWidget);

    await tester.tap(find.text('إعادة تعيين البيانات المحلية'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إعادة تعيين البيانات'));
    await tester.pumpAndSettle();

    expect(resets, 1);
    expect(opens, 2);
    expect(find.byType(LocalDataRepairScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}