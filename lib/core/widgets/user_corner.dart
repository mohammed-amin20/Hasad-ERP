import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../../presentation/providers/auth_providers.dart';

const List<String> _weekdays = [
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];

const List<String> _months = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

String _arabicDate(DateTime now) =>
    '${_weekdays[now.weekday - 1]}، ${now.day} ${_months[now.month - 1]} ${now.year}';

/// Topbar trailing block replicating the HTML header: today's date chip and
/// the current user's avatar circle (initial on blue-100).
class UserCorner extends StatelessWidget {
  const UserCorner({super.key});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 760;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!narrow) ...[
          const _DateChip(),
          const SizedBox(width: 16),
        ],
        const _UserAvatar(),
      ],
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const FaIcon(
          FontAwesomeIcons.calendarDay,
          size: 14,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 6),
        Text(
          _arabicDate(DateTime.now()),
          style: AppTheme.light.textTheme.bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _UserAvatar extends ConsumerWidget {
  const _UserAvatar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final raw = (user?.name ?? user?.email ?? '؟').trim();
    final initial = raw.isEmpty ? '؟' : raw[0];
    return Tooltip(
      message: user?.email ?? '',
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFDBEAFE),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0x1F0F172A), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryDark,
          ),
        ),
      ),
    );
  }
}