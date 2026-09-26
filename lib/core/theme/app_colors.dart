import 'package:flutter/painting.dart';
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
  static const Color sidebarText = Color(0xFF94A3B8);
  static const Color background = Color(0xFFF0F2F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF5B6B84);
  static const Color inputIcon = Color(0xFF94A3B8);

  // Badge pairs (background / foreground) — DESIGN_SYSTEM §2.
  static const Color badgePaidBg = Color(0xFFDCFCE7);
  static const Color badgePaidFg = Color(0xFF166534);
  static const Color badgePartialBg = Color(0xFFFEF9C3);
  static const Color badgePartialFg = Color(0xFF854D0E);
  static const Color badgeUnpaidBg = Color(0xFFFEE2E2);
  static const Color badgeUnpaidFg = Color(0xFF991B1B);
  static const Color badgeCommissionBg = Color(0xFFFEF3C7);
  static const Color badgeCommissionFg = Color(0xFF92400E);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [brandStart, brandEnd],
  );

  // ---- Card system surfaces -------------------------------------------
  // Wide, comfortable, consistent cards: one white surface + hairline
  // border, with soft tinted fills for secondary levels and brand moments.
  static const Color surfaceMuted = Color(0xFFF8FAFC);
  static const Color surfaceSunken = Color(0xFFF1F5F9);
  static const Color borderStrong = Color(0xFFCBD5E1);
  static const Color borderSubtle = Color(0xFFEEF2F7);
  static const Color glassSurface = Color(0xF5FFFFFF);
  static const Color overlayScrim = Color(0x8C0F172A);

  // ---- Soft tinted pairs (background / border / ink) -------------------

  static const Color primarySoft = Color(0xFFEFF6FF);
  static const Color primarySoftBorder = Color(0xFFBFDBFE);
  static const Color secondarySoft = Color(0xFFF5F3FF);
  static const Color secondarySoftBorder = Color(0xFFDDD6FE);
  static const Color successSoft = Color(0xFFF0FDF4);
  static const Color successSoftBorder = Color(0xFFBBF7D0);
  static const Color dangerSoft = Color(0xFFFEF2F2);
  static const Color dangerSoftBorder = Color(0xFFFECACA);
  static const Color warningSoft = Color(0xFFFFFBEB);
  static const Color warningSoftBorder = Color(0xFFFDE68A);
  static const Color brandSoft = Color(0xFFFEF6E7);
  static const Color brandSoftBorder = Color(0xFFF7DFB5);
  static const Color brandInk = Color(0xFF92400E);

  // ---- Chart series ---------------------------------------------------
  // Two series max per chart; always paired with a legend and distinct
  // stroke styles so color is never the only differentiator.

  static const Color chartSales = primary;
  static const Color chartPurchases = secondary;
  static const Color chartProfit = success;
  static const Color chartGrid = Color(0xFFEEF2F7);

  // ---- Elevation ramp (DESIGN_SYSTEM §6) ------------------------------

  static const List<BoxShadow> shadowCard = [
    BoxShadow(color: Color(0x0F0F172A), blurRadius: 3, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> shadowHover = [
    BoxShadow(
      color: Color(0x140F172A),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> shadowDialog = [
    BoxShadow(
      color: Color(0x4D0F172A),
      blurRadius: 50,
      offset: Offset(0, 18),
    ),
  ];
  static Color softFill(Color accent) => accent.withValues(alpha: 0.10);
}
