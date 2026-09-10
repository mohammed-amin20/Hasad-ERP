import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hasad_erp/core/accessibility/reduced_motion.dart';
import 'package:hasad_erp/core/theme/app_theme.dart';
import 'package:hasad_erp/core/widgets/app_progress.dart';
import 'package:hasad_erp/domain/auth/app_role.dart';
import 'package:hasad_erp/domain/auth/app_user.dart';
import 'package:hasad_erp/presentation/providers/auth_providers.dart';
import 'package:hasad_erp/presentation/shell/side_navigation.dart';

void main() {
  group('reduced motion (W8-6)', () {
    Future<Duration> resolveDuration(
      WidgetTester tester,
      bool disableAnimations,
    ) async {
      Duration? result;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              disableAnimations: disableAnimations,
              size: const Size(800, 600),
            ),
            child: Builder(
              builder: (context) {
                result = motionDuration(
                  context,
                  const Duration(milliseconds: 180),
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      return result!;
    }

    testWidgets(
      'motionDuration zeroes out when the OS requests reduced motion',
      (tester) async {
        expect(await resolveDuration(tester, true), Duration.zero);
      },
    );

    testWidgets('motionDuration keeps the preferred duration otherwise', (
      tester,
    ) async {
      expect(
        await resolveDuration(tester, false),
        const Duration(milliseconds: 180),
      );
    });

    testWidgets('AppProgress renders a static arc when reduce motion is on', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              disableAnimations: true,
              size: Size(400, 400),
            ),
            child: const Scaffold(body: Center(child: AppProgress())),
          ),
        ),
      );
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(
        indicator.value,
        isNotNull,
        reason: 'reduced motion should freeze the spinner as a static arc',
      );
    });

    testWidgets('AppProgress keeps the rotating spinner otherwise', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: AppProgress())),
        ),
      );
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(
        indicator.value,
        isNull,
        reason: 'the normal spinner stays indeterminate',
      );
    });

    testWidgets('sidebar animation is instant when the platform asks for '
        'reduced motion', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

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
            home: const Scaffold(
              body: Align(
                alignment: Alignment.centerRight,
                child: SideNavigation(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final animated = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer).first,
      );
      expect(animated.duration, Duration.zero);
    });
  });
}
