import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_lockup.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.sidebarBg,
      body: Center(
        child: BrandLockup(width: 250, onDark: true),
      ),
    );
  }
}