import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Logical-start inset between an input field's border and its leading icon.
///
/// 12 is a DESIGN_SYSTEM §4 multiple of 4, and it is the *same* value stock
/// Flutter already applies to a decorated dropdown's own arrow
/// (`suffixIconEndMargin = (filled || outlined) ? 12.0 : 0.0` in
/// `dropdown.dart`), so a field's leading icon and its trailing arrow end up
/// optically equal.
///
/// The app's `contentPadding` is `EdgeInsets.symmetric(horizontal: 14)`, so the
/// resulting rhythm is: border → icon **12**, border → text **14**, icon → text
/// **14**. Nothing is cramped and nothing is stranded against the border.
const double kFieldIconInset = 12.0;

/// Padding applied to [FieldIcon], in one place so no screen can drift.
const EdgeInsetsDirectional kFieldIconInsetPadding =
    EdgeInsetsDirectional.only(start: kFieldIconInset);

/// An input field's leading icon, inset from the field's logical start border.
///
/// ## Why the theme could not do this
///
/// `InputDecorationTheme` supplies defaults for each *property* of
/// `InputDecoration`, but `prefixIcon` is a `Widget` — a theme cannot transform
/// a widget tree, and neither `TextField` nor `EditableText` wraps
/// `prefixIcon` on the way to the decorator. So the gap has to live in the icon
/// widget itself. Keeping it in one shared component (rather than 76 hand-written
/// `Padding`s) is what makes it a single tunable value.
///
/// ## Why `FaIcon` was the one that touched the border
///
/// `InputDecorator` positions the prefix slot *flush* with the field border:
/// `contentPadding.start` shifts the text, not the icon
/// (`input_decorator.dart`, `centerLayout`). A Material `Icon` re-wraps its
/// glyph in `SizedBox(size, size) + Center`, so the slack inside the 40px slot
/// put ~11px between it and the border for free. `FaIcon` deliberately drops
/// that `SizedBox`/`Center` (see its own doc comment) and hands a bare
/// `RichText` to the slot, and `RenderParagraph` paints text at
/// `TextAlign.start` — in RTL that is the border side. Result: `FaIcon` prefixes
/// measured a **0.00px** gap while `Icon` prefixes measured ~11px. This widget
/// makes the two agree.
///
/// ## Layout safety
///
/// The padding is applied *inside* the slot's `ConstrainedBox`, so the slot
/// still resolves to the same 40×18 box. `prefixIconSize` is therefore
/// unchanged, the content inset is unchanged, and field widths/heights are
/// byte-identical — only the ink moves. See
/// `test/widget/input_field_icon_inset_test.dart`.
class FieldIcon extends StatelessWidget {
  /// A Font Awesome icon (`FontAwesomeIcons.*` are `FaIconData`, **not**
  /// `IconData`, so they need their own constructor).
  const FieldIcon.fa(FaIconData icon, {super.key, this.size, this.color})
    : _fa = icon,
      _material = null;

  /// A Material icon (`Icons.*`, or anything that is an `IconData`).
  const FieldIcon.material(IconData icon, {super.key, this.size, this.color})
    : _fa = null,
      _material = icon;

  final FaIconData? _fa;
  final IconData? _material;

  /// Overrides the resolved icon size. Leave `null` to inherit the decorator's
  /// `IconTheme.size` (18 under this app's `isDense` theme), which is what every
  /// call site did before this widget existed.
  final double? size;

  /// Overrides the tint. Leave `null` to inherit `prefixIconColor` from the
  /// shared `InputDecorationTheme`.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: kFieldIconInsetPadding,
      child: _fa != null
          ? FaIcon(_fa, size: size, color: color)
          : Icon(_material, size: size, color: color),
    );
  }
}
