import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The حصاد mark (DESIGN_SYSTEM.md §1): the wheat tile rendered from the actual
/// brand SVG. Always circle-clipped so the compact mark reads consistently on
/// every surface (user preference).
///
/// [variant] picks the source tile for the surface it sits on:
/// - [BrandMarkVariant.amber] — warp on the amber tile (`hasad-logo-icon-amber`),
///   for light/white surfaces (sidebar, app bar, login card).
/// - [BrandMarkVariant.dark] — gold warp on the slate tile (`hasad-logo-icon`),
///   for dark surfaces (splash, dark panels).
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 40, this.variant = BrandMarkVariant.amber});

  final double size;
  final BrandMarkVariant variant;

  String get _asset => variant == BrandMarkVariant.dark
      ? BrandAssets.iconDark
      : BrandAssets.iconAmber;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'شعار حصاد',
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: ClipOval(
          child: SvgPicture.asset(
            _asset,
            width: size,
            height: size,
            fit: BoxFit.cover,
            semanticsLabel: 'شعار حصاد',
          ),
        ),
      ),
    );
  }
}

enum BrandMarkVariant { amber, dark }

/// Bundled brand SVG asset paths.
abstract final class BrandAssets {
  static const String iconDark = 'assets/logos/hasad-logo-icon.svg';
  static const String iconAmber = 'assets/logos/hasad-logo-icon-amber.svg';
  static const String mono = 'assets/logos/hasad-logo-mono.svg';
  static const String lockupDark = 'assets/logos/hasad-logo-horizontal-dark.svg';
  static const String lockupLight = 'assets/logos/hasad-logo-horizontal-light.svg';
}