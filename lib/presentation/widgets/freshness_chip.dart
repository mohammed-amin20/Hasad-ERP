import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/time_format.dart';
import '../providers/offline_providers.dart';

/// Header pill showing when the current report was last fetched successfully
/// (`report_cache.fetched_at`). Renders empty on web and before the first
/// successful online fetch, so existing headers stay unchanged.
class FreshnessChip extends ConsumerWidget {
  const FreshnessChip({super.key, required this.cacheKey});

  /// The report_cache key the screen's repository wrapper writes to.
  final String cacheKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cachedAt = ref.watch(reportCachedAtProvider(cacheKey)).value;
    if (cachedAt == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final sameDay = cachedAt.year == now.year &&
        cachedAt.month == now.month &&
        cachedAt.day == now.day;
    final timeLabel = TimeFormat.hour12(cachedAt);
    final label = sameDay
        ? timeLabel
        : '${cachedAt.day.toString().padLeft(2, '0')}/'
            '${cachedAt.month.toString().padLeft(2, '0')} '
            '$timeLabel';

    // MediaQuery, not LayoutBuilder: inside PageScaffold's FittedBox the chip
    // gets unbounded width, so a LayoutBuilder could never detect narrow.
    final compact = MediaQuery.sizeOf(context).width < 700;
    return Tooltip(
      message: 'آخر تحديث للبيانات',
      waitDuration: const Duration(milliseconds: 400),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!compact) ...[
              const FaIcon(
                FontAwesomeIcons.clock,
                size: 12,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}