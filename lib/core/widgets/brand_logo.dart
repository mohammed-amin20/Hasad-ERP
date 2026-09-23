import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The حصاد mark (DESIGN_SYSTEM.md §1): the wheat tile rendered from the
/// official brand SVG. The tile is a ready-made squircle (rx=112 built into
/// the artwork), so it renders as-is with `BoxFit.contain` — no extra
/// clipping needed.
///
/// [variant] picks the source tile for the surface it sits on:
/// - [BrandMarkVariant.amber] — amber squircle (`hasad-logo-icon`), for
///   light/white surfaces (sidebar, app bar, login card).
/// - [BrandMarkVariant.dark] — navy squircle (`hasad-logo-icon-navy`), for
///   dark surfaces (splash, dark panels).
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 40, this.variant = BrandMarkVariant.amber});

  final double size;
  final BrandMarkVariant variant;

  String get _asset => variant == BrandMarkVariant.dark
      ? BrandAssets.iconNavy
      : BrandAssets.iconAmber;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'شعار حصاد',
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: SvgPicture.asset(
          _asset,
          width: size,
          height: size,
          fit: BoxFit.contain,
          semanticsLabel: 'شعار حصاد',
        ),
      ),
    );
  }
}

enum BrandMarkVariant { amber, dark }

/// Official Hasad brand kit asset paths (assets/branding/, cleaned SVGs).
abstract final class BrandAssets {
  static const String iconNavy = 'assets/branding/hasad-logo-icon-navy.svg';
  static const String iconAmber = 'assets/branding/hasad-logo-icon.svg';
  static const String iconPresentation = 'assets/branding/hasad-logo-icon-presentation.svg';
  static const String mono = 'assets/branding/hasad-logo-mono.svg';
  static const String lockupDark = 'assets/branding/hasad-logo-horizontal-dark.svg';
  static const String lockupLight = 'assets/branding/hasad-logo-horizontal-light.svg';
  static const String logoMark = 'assets/branding/hasad-logo-mark.png';
}