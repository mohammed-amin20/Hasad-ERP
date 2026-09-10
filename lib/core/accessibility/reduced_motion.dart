import 'package:flutter/widgets.dart';

/// Zeroes out a preferred animation duration when the platform declares the
/// "reduce motion" accessibility preference.
Duration motionDuration(BuildContext context, Duration preferred) {
  return MediaQuery.maybeOf(context)?.disableAnimations ?? false
      ? Duration.zero
      : preferred;
}
