import 'package:flutter/painting.dart';

/// Design-system color tokens (DESIGN_SYSTEM.md §2).
///
/// No widget may hardcode a color that is not one of these tokens.
abstract final class AppColors {
  // Brand / logo gradient.
  static const Color brandStart = Color(0xFFB45309);
  static const Color brandEnd = Color(0xFFF59E0B);

  // Functional.
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color secondary = Color(0xFF7C3AED);

  // Semantic.
  static const Color success = Color(0xFF16A34A);
  static const Color danger = Color(0xFFDC2626);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF2563EB);

  // Neutrals.
  static const Color sidebarBg = Color(0xFF0F172A);
  static const Color sidebarText = Color(0xFFA5B4C6);
  static const Color background = Color(0xFFF0F2F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF5B6B84);

  // Badge pairs (background / foreground) — DESIGN_SYSTEM §2.
  // Commission/Info now uses warning bg + textPrimary fg for 4.5:1 contrast.
  static const Color badgePaidBg = Color(0xFFDCFCE7);
  static const Color badgePaidFg = Color(0xFF166534);
  static const Color badgePartialBg = Color(0xFFFEF9C3);
  static const Color badgePartialFg = Color(0xFF854D0E);
  static const Color badgeUnpaidBg = Color(0xFFFEE2E2);
  static const Color badgeUnpaidFg = Color(0xFF991B1B);
  static const Color badgeCommissionBg = Color(0xFFF59E0B);
  static const Color badgeCommissionFg = Color(0xFF1E293B);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [brandStart, brandEnd],
  );
}