import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_lockup.dart';
import '../../data/offline/local_store.dart';
import 'confirm_dialog.dart';

/// Fatal-store state shown by the app gate when `localStoreProvider` errors
/// (`LocalStoreOpenException`): the local database could not be opened or
/// migrated.
///
/// ## No silent degradation, no silent deletion
///
/// The bug this replaces resolved a failed open to `NullLocalStore`, which made
/// every offline screen look empty on a cold start. Here the user gets two
/// explicit actions instead:
///
/// - **إعادة المحاولة** — re-runs [`localStoreProvider`], hoping a transient
///   lock/file error clears.
/// - **إعادة تعيين البيانات المحلية** — a destructive wipe fronted by a
///   [ConfirmTone.danger] confirmation that explicitly warns unsynced local
///   work is destroyed. It is never invoked automatically on a first failure.
class LocalDataRepairScreen extends ConsumerWidget {
  const LocalDataRepairScreen({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final isMobile = MediaQuery.sizeOf(context).width < 700;

    Future<void> reset() async {
      final confirmed = await showConfirmDialog(
        context,
        title: 'إعادة تعيين البيانات المحلية؟',
        message: 'سيتم حذف قاعدة البيانات المحلية بالكامل على هذا الجهاز، '
            'وسيتم فقدان أي بيانات لم تتم مزامنتها مع الخادم — '
            'مثل الفواتير أو الحركات المحفوظة محلياً. لا يمكن التراجع عن '
            'هذا الإجراء، وقد تحتاج إلى تسجيل الدخول مرة أخرى.',
        confirmLabel: 'إعادة تعيين البيانات',
        icon: FontAwesomeIcons.triangleExclamation,
        tone: ConfirmTone.danger,
      );
      if (!confirmed) return;
      try {
        // Release the live connection first (Windows cannot delete an open
        // sqlite file), then delete the file, then re-open a fresh database.
        final store = ref
            .read(localStoreProvider)
            .maybeWhen(data: (s) => s, orElse: () => null);
        if (store is DriftLocalStore) {
          await store.dispose();
        }
        await ref.read(resetLocalDatabaseProvider)();
        ref.invalidate(localStoreProvider);
      } on Object catch (err) {
        messenger.showSnackBar(
          SnackBar(content: Text('تعذرت إعادة تعيين البيانات: $err')),
        );
      }
    }

    final card = ConstrainedBox(
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
                  color: AppColors.danger.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: FaIcon(
                    FontAwesomeIcons.circleExclamation,
                    size: 28,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'تعذر فتح البيانات المحلية',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'تعذرت قراءة قاعدة البيانات المحلية على هذا الجهاز. '
              'أعد المحاولة أولاً — وإذا استمرت المشكلة، يمكنك إعادة تعيين '
              'البيانات المحلية، مع العلم أنها قد تحذف بيانات غير مزامنة '
              'لن تُسترجع مرة أخرى.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Text(
                error.toString(),
                textAlign: TextAlign.start,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(localStoreProvider),
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
              onPressed: reset,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                foregroundColor: AppColors.danger,
                side: BorderSide(color: AppColors.danger.withValues(alpha: 0.6)),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              icon: const FaIcon(FontAwesomeIcons.eraser, size: 16),
              label: const Text('إعادة تعيين البيانات المحلية'),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: isMobile
            ? card
            : Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: card,
                ),
              ),
      ),
    );
  }
}