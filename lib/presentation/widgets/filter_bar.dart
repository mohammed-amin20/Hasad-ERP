import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/hasad_card.dart';

class FilterBar extends StatelessWidget {
  const FilterBar({
    super.key,
    this.searchController,
    this.hintText = 'بحث…',
    this.onSearchChanged,
    this.onClearSearch,
    this.children = const [],
  });

  final TextEditingController? searchController;
  final String hintText;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onClearSearch;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return HasadCard(
      padding: const EdgeInsets.all(AppConfig.cardPaddingSmall),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < AppConfig.breakpointNarrow;
          final search = TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: hintText,
              prefixIcon: const FaIcon(FontAwesomeIcons.magnifyingGlass, size: 15),
              suffixIcon: (searchController?.text.isNotEmpty ?? false) &&
                      onClearSearch != null
                  ? IconButton(
                      tooltip: 'مسح البحث',
                      onPressed: onClearSearch,
                      icon: const FaIcon(FontAwesomeIcons.xmark, size: 14),
                    )
                  : null,
            ),
          );

          if (children.isEmpty) return search;

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                search,
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: children,
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 16),
              ...children.expand(
                (child) => [child, const SizedBox(width: 12)],
              ),
            ],
          );
        },
      ),
    );
  }
}

class DateRangeChip extends StatelessWidget {
  const DateRangeChip({
    super.key,
    required this.label,
    this.onTap,
    this.onClear,
  });

  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final chip = ActionChip(
      avatar: const FaIcon(FontAwesomeIcons.calendarDays, size: 12),
      label: Text(label),
      onPressed: onTap,
      tooltip: 'تصفية حسب التاريخ',
      side: const BorderSide(color: AppColors.border),
      backgroundColor: AppColors.surfaceMuted,
      shape: const StadiumBorder(),
      labelStyle: const TextStyle(
        fontFamily: 'Cairo',
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
    if (onClear == null) return chip;
    return InputChip(
      avatar: const FaIcon(FontAwesomeIcons.calendarDays, size: 12),
      label: Text(label),
      onPressed: onTap,
      onDeleted: onClear,
      deleteIcon: const FaIcon(FontAwesomeIcons.xmark, size: 11),
      deleteButtonTooltipMessage: 'مسح التاريخ',
      tooltip: 'تصفية حسب التاريخ',
      side: const BorderSide(color: AppColors.border),
      backgroundColor: AppColors.surfaceMuted,
      shape: const StadiumBorder(),
      labelStyle: const TextStyle(
        fontFamily: 'Cairo',
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }
}
