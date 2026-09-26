import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../config/app_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';

class HasadCard extends StatelessWidget {
  const HasadCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.accent,
    this.color,
    this.borderColor,
    this.borderRadius,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? accent;
  final Color? color;
  final Color? borderColor;
  final BorderRadius? borderRadius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppConfig.cardRadius);
    final interactive = onTap != null;

    Widget content = Padding(
      padding: padding ?? const EdgeInsets.all(AppConfig.cardPadding),
      child: child,
    );

    if (semanticLabel != null) {
      content = Semantics(
        label: semanticLabel,
        container: interactive,
        button: interactive,
        child: content,
      );
    }

    return AnimatedContainer(
      duration: AppMotion.of(context, AppMotion.fast),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: radius,
        border: Border.all(color: borderColor ?? AppColors.border),
        boxShadow: AppColors.shadowCard,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          color: Colors.transparent,
          child: interactive
              ? InkWell(
                  onTap: onTap,
                  hoverColor: AppColors.primary.withValues(alpha: 0.04),
                  splashColor: AppColors.primary.withValues(alpha: 0.08),
                  child: content,
                )
              : content,
        ),
      ),
    );
  }
}

class InteractiveCard extends StatefulWidget {
  const InteractiveCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.accent,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final Color? accent;
  final String? semanticLabel;

  @override
  State<InteractiveCard> createState() => _InteractiveCardState();
}

class _InteractiveCardState extends State<InteractiveCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppConfig.cardRadius);
    final content = Padding(
      padding: widget.padding ?? const EdgeInsets.all(AppConfig.cardPadding),
      child: widget.child,
    );

    final body = Stack(
      children: [
        content,
        if (widget.accent != null)
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            child: Container(width: 4, color: widget.accent),
          ),
      ],
    );

    return MouseRegion(
      cursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      onEnter: widget.onTap == null
          ? null
          : (_) => setState(() => _hovered = true),
      onExit: widget.onTap == null
          ? null
          : (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppMotion.of(context, AppMotion.normal),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: radius,
          border: Border.all(
            color: _hovered ? AppColors.borderStrong : AppColors.border,
          ),
          boxShadow: _hovered ? AppColors.shadowHover : AppColors.shadowCard,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              hoverColor: Colors.transparent,
              splashColor: AppColors.primary.withValues(alpha: 0.06),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}

class IconChip extends StatelessWidget {
  const IconChip({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
    this.iconSize = 18,
    this.circular = true,
  });

  final FaIconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.softFill(color),
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular ? null : BorderRadius.circular(12),
      ),
      child: FaIcon(icon, size: iconSize, color: color),
    );
  }
}

class CardHeader extends StatelessWidget {
  const CardHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.trailing,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final FaIconData? icon;
  final Color? iconColor;
  final Widget? trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: (compact
                  ? theme.textTheme.titleMedium
                  : theme.textTheme.titleLarge)
              ?.copyWith(fontWeight: FontWeight.w700),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );

    final leading = (icon == null)
        ? titleBlock
        : Row(
            children: [
              IconChip(
                icon: icon!,
                color: iconColor ?? AppColors.primary,
                size: compact ? 32 : 40,
                iconSize: compact ? 15 : 18,
              ),
              const SizedBox(width: 12),
              Expanded(child: titleBlock),
            ],
          );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: leading),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}
