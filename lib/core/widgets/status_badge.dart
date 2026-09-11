import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../../domain/invoices/invoice.dart';

/// Colour pair for the design-system status badges (DESIGN_SYSTEM §2).
class BadgePalette {
  const BadgePalette({required this.background, required this.foreground});

  final Color background;
  final Color foreground;

  static const paid = BadgePalette(
    background: AppColors.badgePaidBg,
    foreground: AppColors.badgePaidFg,
  );
  static const partial = BadgePalette(
    background: AppColors.badgePartialBg,
    foreground: AppColors.badgePartialFg,
  );
  static const unpaid = BadgePalette(
    background: AppColors.badgeUnpaidBg,
    foreground: AppColors.badgeUnpaidFg,
  );
  static const commission = BadgePalette(
    background: AppColors.badgeCommissionBg,
    foreground: AppColors.badgeCommissionFg,
  );
}

/// Pill-shaped status badge used across lists.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.palette});

  final String label;
  final BadgePalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: palette.foreground,
        ),
      ),
    );
  }
}

/// Palette for an invoice payment status.
BadgePalette badgeForStatus(InvoiceStatus status) => switch (status) {
  InvoiceStatus.paid => BadgePalette.paid,
  InvoiceStatus.partial => BadgePalette.partial,
  InvoiceStatus.unpaid => BadgePalette.unpaid,
};

/// Palette for an invoice ownership badge.
BadgePalette badgeForOwnership(InvoiceOwnership ownership) =>
    ownership == InvoiceOwnership.consignment
    ? BadgePalette.commission
    : const BadgePalette(
        background: AppColors.border,
        foreground: AppColors.textPrimary,
      );
