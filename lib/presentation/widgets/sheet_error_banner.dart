import 'package:flutter/material.dart';
import 'package:hasad_erp/core/theme/app_colors.dart';

/// Inline error banner for a form sheet.
///
/// A sheet must show why a submission failed and stay open so the user can fix
/// it. The previous behaviour popped nothing and relied on the caller
/// re-opening the sheet, which is a re-entry, not a correction — and a
/// `double.parse` that throws *before* the submit `try` block never reached any
/// error UI at all, so the sheet simply stopped responding with no explanation.
///
/// Deliberately not a SnackBar: a SnackBar is for the success path and vanishes
/// before a user has read it. Kept in the sheet's own scroll view so it scrolls
/// with the fields it refers to.
class SheetErrorBanner extends StatelessWidget {
  const SheetErrorBanner(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            size: 20,
            color: AppColors.danger,
            // Announced by a screen reader as soon as it appears, which a
            // SnackBar's 4s lifetime would not survive.
            semanticLabel: 'خطأ',
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
