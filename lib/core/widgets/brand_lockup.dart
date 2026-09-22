import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'brand_logo.dart';

/// The full حصاد lockup: wheat mark + Arabic wordmark + Latin submark,
/// composing the `hasad-logo-horizontal-*.svg` design in Flutter with the
/// bundled Cairo font (guarantees correct Arabic shaping and crisp scaling).
///
/// [onDark] selects the variant: white wordmark on dark surfaces, slate on
/// light ones — mirroring the dark/light horizontal SVG files.
class BrandLockup extends StatelessWidget {
  const BrandLockup({
    super.key,
    this.width = 220,
    this.onDark = false,
  });

  final double width;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final markSize = width * 0.24;
    final wordSize = width * 0.095;
    final subSize = width * 0.028;
    final gap = width * 0.022;

    final wordColor = onDark ? Colors.white : AppColors.textPrimary;
    final subColor = onDark ? AppColors.warning : AppColors.brandStart;

    return Semantics(
      label: 'شعار حصاد',
      image: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BrandLogo(
            size: markSize,
            variant: onDark ? BrandMarkVariant.dark : BrandMarkVariant.amber,
          ),
          SizedBox(width: gap),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'حصاد',
                style: TextStyle(
                  fontSize: wordSize,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  color: wordColor,
                ),
              ),
              SizedBox(height: gap * 0.4),
              Text(
                'HASAD',
                style: TextStyle(
                  fontSize: subSize,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  letterSpacing: wordSize * 0.045,
                  color: subColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}