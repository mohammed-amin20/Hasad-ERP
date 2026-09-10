import 'package:flutter/material.dart';

/// Loading indicator that honors the platform "reduce motion" preference.
///
/// When animations are disabled it renders a fixed arc (a determinate bar at
/// a static value) instead of an infinitely rotating spinner, keeping loading
/// state visible without continuous motion.
class AppProgress extends StatelessWidget {
  const AppProgress({super.key, this.strokeWidth = 4.0, this.color});

  final double strokeWidth;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return CircularProgressIndicator(
      value: reduceMotion ? 0.25 : null,
      strokeWidth: strokeWidth,
      color: color,
    );
  }
}
