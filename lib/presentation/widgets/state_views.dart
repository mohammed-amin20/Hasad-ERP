import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/widgets/hasad_card.dart';

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.compact = false,
  });

  final FaIconData icon;
  final String title;
  final String message;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HasadCard(
      padding: EdgeInsets.symmetric(
        horizontal: AppConfig.cardPadding,
        vertical: compact ? 28 : 40,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: FaIcon(icon, size: 26, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}

class ErrorStateCard extends StatelessWidget {
  const ErrorStateCard({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
    this.retryLabel = 'إعادة المحاولة',
    this.icon = FontAwesomeIcons.triangleExclamation,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final FaIconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.danger,
          ),
        ),
        const SizedBox(height: 4),
        Text(message, style: theme.textTheme.bodySmall),
      ],
    );

    return HasadCard(
      accent: AppColors.danger,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 480;
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconChip(
                      icon: icon,
                      color: AppColors.danger,
                      size: 40,
                      iconSize: 18,
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: details),
                  ],
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: const FaIcon(FontAwesomeIcons.rotateRight, size: 13),
                      iconAlignment: IconAlignment.end,
                      label: Text(retryLabel),
                    ),
                  ),
                ],
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconChip(
                icon: icon,
                color: AppColors.danger,
                size: 40,
                iconSize: 18,
              ),
              const SizedBox(width: 16),
              Expanded(child: details),
              if (onRetry != null) ...[
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const FaIcon(FontAwesomeIcons.rotateRight, size: 13),
                  iconAlignment: IconAlignment.end,
                  label: Text(retryLabel),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = 8,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.of(context, const Duration(milliseconds: 1100));
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = duration == Duration.zero ? 0.0 : _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(
              AppColors.surfaceSunken,
              AppColors.borderSubtle,
              t,
            ),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.lines = 3, this.height});

  final int lines;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return HasadCard(
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(width: 140, height: 16),
            const SizedBox(height: 16),
            for (var i = 0; i < lines; i++) ...[
              SkeletonBox(width: i.isEven ? double.infinity : 220),
              if (i != lines - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 4, this.itemHeight = 72});

  final int count;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i++) ...[
          HasadCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                const SkeletonBox(width: 40, height: 40, borderRadius: 12),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: itemHeight * 2.4, height: 13),
                      const SizedBox(height: 10),
                      const SkeletonBox(width: double.infinity, height: 11),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (i != count - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}
