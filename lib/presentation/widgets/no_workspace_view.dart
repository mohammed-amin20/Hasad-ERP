import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/error/app_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_lockup.dart';
import '../providers/auth_providers.dart';
class NoWorkspaceView extends ConsumerWidget {
  const NoWorkspaceView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = MediaQuery.sizeOf(context).width < 700;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: isMobile
            ? const _NoWorkspaceCard()
            : Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: const _NoWorkspaceCard(),
                  ),
                ),
              ),
      ),
    );
  }
}

class _NoWorkspaceCard extends ConsumerWidget {
  const _NoWorkspaceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final isSigningOut = ref.watch(tenantSwitchProvider).isLoading;

    void retry() {
      ref.invalidate(availableTenantsProvider);
      ref.invalidate(authStateProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('جارٍ إعادة المحاولة…')),
      );
    }

    Future<void> signOut() async {
      try {
        await ref.read(authRepositoryProvider).signOut();
      } on Object catch (error) {
        messenger.showSnackBar(
          SnackBar(content: Text(mapErrorToAppException(error).message)),
        );
      }
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F0F172A),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: BrandLockup(width: 200)),
            const SizedBox(height: 24),
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: FaIcon(
                    FontAwesomeIcons.buildingCircleExclamation,
                    size: 28,
                    color: AppColors.brandStart,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد منشأة بعد',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'حسابك غير مرتبط بأي منشأة حتى الآن. تواصل مع الإدارة '
              'لتسجيل منشأتك، أو أعد المحاولة — ويمكنك تسجيل الخروج بأمان '
              'في أي وقت.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: retry,
              icon: const FaIcon(FontAwesomeIcons.rotate, size: 16),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: isSigningOut ? null : signOut,
              icon: const FaIcon(
                FontAwesomeIcons.arrowRightFromBracket,
                size: 16,
              ),
              label: const Text('تسجيل الخروج'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}