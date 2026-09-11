import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The حصاد mark: wheat icon on the gold gradient tile (DESIGN_SYSTEM.md §1).
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        shape: BoxShape.circle,
      ),
      child: FaIcon(
        FontAwesomeIcons.wheatAwn,
        color: Colors.white,
        semanticLabel: 'شعار حصاد',
        size: size * 0.5,
      ),
    );
  }
}
