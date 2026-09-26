import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/hasad_card.dart';

class RecordColumn<T> {
  const RecordColumn({
    required this.label,
    required this.cell,
    this.flex = 1,
    this.alignment = AlignmentDirectional.centerStart,
    this.primary = false,
    this.emphasis = false,
  });

  final String label;
  final Widget Function(BuildContext context, T item) cell;
  final int flex;
  final AlignmentGeometry alignment;
  final bool primary;
  final bool emphasis;
}

class RecordTable<T> extends StatelessWidget {
  const RecordTable({
    super.key,
    required this.items,
    required this.columns,
    this.onTap,
    this.trailing,
    this.padding = EdgeInsets.zero,
  });

  final List<T> items;
  final List<RecordColumn<T>> columns;
  final void Function(T item)? onTap;
  final Widget Function(BuildContext context, T item)? trailing;
  final EdgeInsetsGeometry padding;

  RecordColumn<T> get _primary =>
      columns.firstWhere((c) => c.primary, orElse: () => columns.first);

  List<RecordColumn<T>> get _secondary => columns
      .where((c) => !c.primary && !(trailing != null && identical(c, columns.last)))
      .toList();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < AppConfig.breakpointNarrow;
        return narrow ? _cards(context) : _table(context);
      },
    );
  }

  Widget _cards(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            InteractiveCard(
              padding: const EdgeInsets.all(AppConfig.cardPaddingSmall),
              onTap: onTap == null ? null : () => onTap!(items[i]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DefaultTextStyle.merge(
                              style: theme.textTheme.titleSmall!,
                              child: _primary.cell(context, items[i]),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _primary.label,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (trailing != null) trailing!(context, items[i]),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final column in _secondary) ...[
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            column.label,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: DefaultTextStyle.merge(
                            textAlign: TextAlign.end,
                            style: column.emphasis
                                ? theme.textTheme.bodyMedium!.copyWith(
                                    fontWeight: FontWeight.w700,
                                  )
                                : theme.textTheme.bodyMedium!,
                            child: column.cell(context, items[i]),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            if (i != items.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _table(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <Widget>[];
    rows.add(
      Row(
        children: [
          for (final column in columns) ...[
            Expanded(
              flex: column.flex,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  column.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ],
          if (trailing != null) const SizedBox(width: 12),
        ],
      ),
    );
    
    rows.add(const SizedBox(height: 4));
    rows.add(const Divider(height: 1));

    for (var i = 0; i < items.length; i++) {
      rows.addAll(_buildRow(context, i));
    }
    
    return SingleChildScrollView(
      child: HasadCard(
        padding: padding,
        child: Column(children: rows),
      ),
    );
  }

  List<Widget> _buildRow(BuildContext context, int i) {
    final theme = Theme.of(context);
    final rowWidgets = <Widget>[
      MouseRegion(
        cursor: onTap == null
            ? MouseCursor.defer
            : SystemMouseCursors.click,
        child: InkWell(
          onTap: onTap == null ? null : () => onTap!(items[i]),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                for (final column in columns) ...[
                  Expanded(
                    flex: column.flex,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DefaultTextStyle.merge(
                        style: column.emphasis
                            ? theme.textTheme.bodyMedium!.copyWith(
                                fontWeight: FontWeight.w800,
                              )
                            : theme.textTheme.bodyMedium!,
                        child: column.cell(context, items[i]),
                      ),
                    ),
                  ),
                ],
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!(context, items[i]),
                ],
              ],
            ),
          ),
        ),
      ),
    ];
    if (i != items.length - 1) {
      rowWidgets.add(const Divider(height: 1));
    }
    return rowWidgets;
  }
}