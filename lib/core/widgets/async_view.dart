import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../error/app_exception.dart';
import '../../presentation/widgets/state_views.dart';

class AsyncSection<T> extends StatelessWidget {
  const AsyncSection({
    super.key,
    required this.value,
    required this.builder,
    required this.onRetry,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.emptyIcon,
    this.emptyAction,
    this.skeletonCount = 4,
  });

  final AsyncValue<T> value;
  final Widget Function(BuildContext context, T data) builder;
  final VoidCallback onRetry;
  final String emptyTitle;
  final String emptyMessage;
  final FaIconData emptyIcon;
  final Widget? emptyAction;
  final int skeletonCount;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => SkeletonList(count: skeletonCount),
      error: (error, _) => SingleChildScrollView(
        padding: const EdgeInsets.only(top: 8),
        child: ErrorStateCard(
          title: 'تعذر تحميل البيانات',
          message: mapErrorToAppException(error).message,
          onRetry: onRetry,
        ),
      ),
      data: (data) {
        if (data is Iterable && data.isEmpty) {
          return SingleChildScrollView(
            child: EmptyStateCard(
              icon: emptyIcon,
              title: emptyTitle,
              message: emptyMessage,
              action: emptyAction,
            ),
          );
        }
        return builder(context, data);
      },
    );
  }
}

class ErrorStateView extends StatelessWidget {
  const ErrorStateView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ErrorStateCard(
          title: 'حدث خطأ',
          message: message,
          onRetry: onRetry,
        ),
      ),
    );
  }
}
