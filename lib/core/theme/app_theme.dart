import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Single source of truth for the app ThemeData (DESIGN_SYSTEM.md §3, §5, §8, §12).
abstract final class AppTheme {
  static ThemeData get light => _theme;

  // Cairo variable font is bundled and registered in pubspec under the
  // "Cairo" family; it covers all weights from 200-1000.
  static const TextStyle _baseText = TextStyle(fontFamily: 'Cairo');

  static final ThemeData _theme = ThemeData(
    useMaterial3: true,
    colorScheme: _colorScheme,
    textTheme: TextTheme(
      displayLarge: _baseText.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
      headlineMedium: _baseText.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
      titleMedium: _baseText.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      bodyLarge: _baseText.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      ),
      bodySmall: _baseText.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      ),
      labelSmall: _baseText.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
scaffoldBackgroundColor: AppColors.background,
      focusColor: AppColors.primary.withValues(alpha: 0.12),
      hoverColor: AppColors.primary.withValues(alpha: 0.08),
      highlightColor: AppColors.primary.withValues(alpha: 0.12),
      splashFactory: InkSparkle.splashFactory,
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 1,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      labelStyle: _baseText.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
      hintStyle: const TextStyle(color: AppColors.textMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.surface,
        disabledBackgroundColor: AppColors.textMuted,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        minimumSize: const Size.fromHeight(48),
        textStyle: _baseText.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
      ).copyWith(
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return AppColors.surface.withValues(alpha: 0.12);
          }
          if (states.contains(WidgetState.pressed)) {
            return AppColors.surface.withValues(alpha: 0.24);
          }
          return null;
        }),
        elevation: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered)
              ? 3
              : states.contains(WidgetState.pressed)
                  ? 0
                  : 1,
        ),
        shape: _focusRing(10),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size(48, 48),
        textStyle: _baseText.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      ).copyWith(
        overlayColor: _buttonOverlay(),
        shape: _focusRing(10),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size(48, 48),
        side: const BorderSide(color: AppColors.primary),
        textStyle: _baseText.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      ).copyWith(
        overlayColor: _buttonOverlay(),
        side: WidgetStateProperty.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.focused)
                ? AppColors.primaryDark
                : AppColors.primary,
            width: states.contains(WidgetState.focused) ? 2 : 1,
          ),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ).copyWith(
        overlayColor: _buttonOverlay(),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.textPrimary,
      contentTextStyle: _baseText.copyWith(fontSize: 13, color: AppColors.surface),
    ),
  );

  /// Hover/focus/pressed overlay tint applied to all button variants.
  static WidgetStateProperty<Color?> _buttonOverlay() {
    return WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return AppColors.primary.withValues(alpha: 0.10);
      }
      if (states.contains(WidgetState.pressed)) {
        return AppColors.primary.withValues(alpha: 0.20);
      }
      return null;
    });
  }

  /// 2px primary focus ring (rounded [radius]) so keyboard navigation
  /// is always visible; idles to a borderless rounded shape.
  static WidgetStateProperty<RoundedRectangleBorder> _focusRing(
    double radius,
  ) {
    return WidgetStateProperty.resolveWith((states) {
      final shape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      );
      if (states.contains(WidgetState.focused)) {
        return shape.copyWith(
          side: const BorderSide(color: AppColors.primary, width: 2),
        );
      }
      return shape;
    });
  }

  static const ColorScheme _colorScheme = ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: AppColors.surface,
    primaryContainer: Color(0xFFDBEAFE),
    onPrimaryContainer: AppColors.textPrimary,
    secondary: AppColors.secondary,
    onSecondary: AppColors.surface,
    error: AppColors.danger,
    onError: AppColors.surface,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textSecondary,
    outline: AppColors.border,
  );
}