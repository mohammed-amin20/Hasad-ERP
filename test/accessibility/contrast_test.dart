import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/theme/app_colors.dart';
import 'package:hasad_erp/core/widgets/status_badge.dart';

double _linearize(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _linearize(c.r) +
    0.7152 * _linearize(c.g) +
    0.0722 * _linearize(c.b);

/// WCAG 2.1 relative-luminance contrast ratio between two colours.
double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

/// WCAG AA for normal-size text is 4.5:1.
void expectAa(Color foreground, Color background, String label) {
  final ratio = _contrast(foreground, background);
  expect(
    ratio,
    greaterThanOrEqualTo(4.5),
    reason: '$label $ratio:1 < 4.5:1',
  );
}

void main() {
  group('AppColors text-on-surface', () {
    test('textPrimary on surface', () {
      expectAa(AppColors.textPrimary, AppColors.surface, 'textPrimary');
    });

    test('textSecondary on surface', () {
      expectAa(AppColors.textSecondary, AppColors.surface, 'textSecondary');
    });

    test('textMuted on surface', () {
      expectAa(AppColors.textMuted, AppColors.surface, 'textMuted');
    });

    test('textMuted on app background', () {
      expectAa(AppColors.textMuted, AppColors.background, 'textMuted(bg)');
    });

    test('primary on surface', () {
      expectAa(AppColors.primary, AppColors.surface, 'primary');
    });

    test('primaryDark on surface', () {
      expectAa(AppColors.primaryDark, AppColors.surface, 'primaryDark');
    });

    test('danger on surface', () {
      expectAa(AppColors.danger, AppColors.surface, 'danger');
    });
  });

  group('AppColors sidebar', () {
    test('sidebarText on sidebarBg', () {
      expectAa(AppColors.sidebarText, AppColors.sidebarBg, 'sidebarText');
    });
  });

  group('StatusBadge palettes', () {
    test('paid', () {
      expectAa(
        BadgePalette.paid.foreground,
        BadgePalette.paid.background,
        'paid',
      );
    });

    test('partial', () {
      expectAa(
        BadgePalette.partial.foreground,
        BadgePalette.partial.background,
        'partial',
      );
    });

    test('unpaid', () {
      expectAa(
        BadgePalette.unpaid.foreground,
        BadgePalette.unpaid.background,
        'unpaid',
      );
    });

    test('commission', () {
      expectAa(
        BadgePalette.commission.foreground,
        BadgePalette.commission.background,
        'commission',
      );
    });

    test('ownership default (textPrimary on border)', () {
      expectAa(AppColors.textPrimary, AppColors.border, 'ownership');
    });
  });
}