import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/error/app_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand_logo.dart';
import '../providers/auth_providers.dart';
import '../providers/navigation_providers.dart';
import 'app_tabs.dart';

/// Sidebar content shared by the fixed/collapsible sidebar and the drawer.
class SideNavigation extends ConsumerWidget {
  const SideNavigation({
    super.key,
    this.collapsed = false,
    this.onToggleCollapse,
  });

  final bool collapsed;
  final VoidCallback? onToggleCollapse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final selected = ref.watch(currentDestinationProvider);
    final visibleTabs = <int>[
      for (final entry in appTabs.indexed)
        if (user == null || entry.$2.allowedFor(user)) entry.$1,
    ];

    return Material(
      color: AppColors.sidebarBg,
      child: SizedBox(
        width: collapsed
            ? AppConfig.sidebarCollapsedWidth
            : AppConfig.sidebarExpandedWidth,
        child: Column(
          children: [
            _Header(collapsed: collapsed, onToggleCollapse: onToggleCollapse),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: visibleTabs.length + 1, // +1 sign-out row
                itemBuilder: (context, i) {
                  if (i == visibleTabs.length) return _SignOut(collapsed: collapsed);
                  final globalIndex = visibleTabs[i];
                  return _NavItem(
                    tab: appTabs[globalIndex],
                    collapsed: collapsed,
                    active: selected == globalIndex,
                    onTap: () {
                      ref.read(currentDestinationProvider.notifier)
                          .select(globalIndex);
                      Navigator.of(context).maybePop();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.collapsed, this.onToggleCollapse});

  final bool collapsed;
  final VoidCallback? onToggleCollapse;

  @override
  Widget build(BuildContext context) {
    final showLabel = !collapsed;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const BrandLogo(size: 32),
          if (showLabel) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'حصاد',
                style: AppTheme.light.textTheme.titleMedium
                    ?.copyWith(color: Colors.white),
              ),
            ),
            if (onToggleCollapse != null)
              IconButton(
                onPressed: onToggleCollapse,
                tooltip: collapsed ? 'توسيع القائمة' : 'طي القائمة',
                color: AppColors.sidebarText,
                icon: FaIcon(
                  collapsed
                      ? FontAwesomeIcons.chevronRight
                      : FontAwesomeIcons.chevronLeft,
                  size: 16,
                ),
              ),
          ] else if (onToggleCollapse != null)
            const Spacer(),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.collapsed,
    required this.active,
    required this.onTap,
  });

  final AppTab tab;
  final bool collapsed;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final showLabel = !collapsed;
    final color = active ? Colors.white : AppColors.sidebarText;
    return Semantics(
      selected: active,
      label: tab.title,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 48,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary.withValues(alpha: 0.35)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.transparent,
            ),
          ),
          child: Stack(
            children: [
              if (active)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Container(
                    width: 3,
                    height: 32,
                    color: AppColors.primary,
                  ),
                ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: collapsed ? 0 : 12,
                  vertical: 0,
                ),
                child: Row(
                  mainAxisAlignment: collapsed
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    Icon(tab.icon.data, color: color, size: 20),
                    if (showLabel) ...[
                      const SizedBox(width: 14),
                      Flexible(
                        child: Text(
                          tab.title,
                          style: AppTheme.light.textTheme.bodyLarge
                              ?.copyWith(color: color, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignOut extends ConsumerWidget {
  const _SignOut({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showLabel = !collapsed;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            await ref.read(authRepositoryProvider).signOut();
          } on Object catch (error) {
            final message = mapErrorToAppException(error).message;
            messenger.showSnackBar(SnackBar(content: Text(message)));
          }
        },
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment:
                collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(
                FontAwesomeIcons.arrowRightFromBracket.data,
                color: AppColors.sidebarText,
                size: 18,
              ),
              if (showLabel) ...[
                const SizedBox(width: 14),
                Text(
                  'تسجيل الخروج',
                  style: AppTheme.light.textTheme.bodyLarge
                      ?.copyWith(color: AppColors.sidebarText),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}