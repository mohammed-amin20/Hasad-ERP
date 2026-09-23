import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_lockup.dart';

/// Branded splash shown while the session is loading: a navy ambience with
/// two brand radial glows, a slowly breathing amber halo behind the official
/// squircle mark, and a fade/scale entrance for the lockup.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sidebarBg,
      body: Stack(
        children: [
          Positioned(
            top: -220,
            right: -140,
            width: 560,
            height: 560,
            child: _Glow(
              opacity: _controller,
              start: 0.9,
              end: 1.15,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.28),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -180,
            left: -150,
            width: 600,
            height: 600,
            child: _Glow(
              opacity: _controller,
              start: 0.9,
              end: 1.1,
              gradient: RadialGradient(
                colors: [
                  AppColors.brandStart.withValues(alpha: 0.22),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: _controller,
                curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
              ),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.94, end: 1.0).animate(
                  CurvedAnimation(
                    parent: _controller,
                    curve: const Interval(0.1, 0.7, curve: Curves.easeOutBack),
                  ),
                ),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.7, end: 1.0).animate(
                    CurvedAnimation(
                      parent: _controller,
                      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.brandEnd.withValues(alpha: 0.20),
                              AppColors.brandEnd.withValues(alpha: 0.07),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: const SizedBox(width: 250, height: 250),
                      ),
                      const BrandLockup(width: 230, onDark: true),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({
    required this.opacity,
    required this.start,
    required this.end,
    required this.gradient,
  });

  final Animation<double> opacity;
  final double start;
  final double end;
  final RadialGradient gradient;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: opacity.drive(Tween(begin: start, end: end)),
      child: DecoratedBox(
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient),
      ),
    );
  }
}