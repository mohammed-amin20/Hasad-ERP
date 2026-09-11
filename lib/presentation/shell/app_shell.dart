import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/widgets/app_progress.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/skip_link.dart';
import '../../domain/auth/app_role.dart';
import '../../domain/auth/app_user.dart';
import '../providers/auth_providers.dart';
import '../providers/navigation_providers.dart';
import '../widgets/connectivity_listener.dart';
import '../widgets/retry_widgets.dart';
import 'app_tabs.dart';
import 'side_navigation.dart';

/// Responsive shell (DESIGN_SYSTEM.md §9 + AGENTS.md):
/// - `> 1100`  fixed expanded sidebar
/// - `700-1100` collapsible sidebar (icon-only when collapsed)
/// - `< 700`    swipeable drawer on the AppBar
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _sidebarCollapsed = false;
  final GlobalKey<ScaffoldState> _shellKey = GlobalKey<ScaffoldState>();
  final FocusNode _contentFocus = FocusNode(
    debugLabel: 'main-content-target',
    skipTraversal: true,
  );

  @override
  void dispose() {
    _contentFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= AppConfig.breakpointDesktop;
    final hasSidebar = width >= AppConfig.breakpointNarrow;
    final collapsed = isDesktop ? false : _sidebarCollapsed;

    return ConnectivityListener(
      child: Scaffold(
        key: _shellKey,
        body: SkipLink(
          target: _contentFocus,
          child: hasSidebar
              ? Row(
                  children: [
                    SideNavigation(
                      collapsed: collapsed,
                      onToggleCollapse: isDesktop
                          ? null
                          : () => setState(
                              () => _sidebarCollapsed = !_sidebarCollapsed,
                            ),
                    ),
                    Expanded(
                      child: _ScreenBody(
                        user: user,
                        contentFocus: _contentFocus,
                        onOpenDrawer: () =>
                            _shellKey.currentState?.openDrawer(),
                      ),
                    ),
                  ],
                )
              : _ScreenBody(
                  user: user,
                  contentFocus: _contentFocus,
                  onOpenDrawer: () => _shellKey.currentState?.openDrawer(),
                ),
        ),
        drawer: hasSidebar ? null : const SideNavigation(),
      ),
    );
  }
}

class _ScreenBody extends ConsumerWidget {
  const _ScreenBody({
    required this.user,
    required this.contentFocus,
    required this.onOpenDrawer,
  });

  final AppUser? user;
  final FocusNode contentFocus;
  final VoidCallback onOpenDrawer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(currentDestinationProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < AppConfig.breakpointNarrow;
    final visible =
        user == null ||
        (index >= 0 &&
            index < appTabs.length &&
            appTabs[index].allowedFor(user!));
    final body = visible && index >= 0 && index < appScreens.length
        ? appScreens[index]
        : const SizedBox.shrink();

    return Scaffold(
      appBar: isMobile
          ? _MobileAppBar(user: user, onOpenDrawer: onOpenDrawer)
          : null,
      body: Column(
        children: [
          const OfflineBanner(),
          if (user != null && !user!.hasTenant) const _OnboardingBanner(),
          Expanded(
            child: Focus(focusNode: contentFocus, child: body),
          ),
        ],
      ),
    );
  }
}

/// Mobile AppBar with tenant switcher for < 700px.
class _MobileAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _MobileAppBar({required this.user, required this.onOpenDrawer});

  final AppUser? user;
  final VoidCallback onOpenDrawer;

  @override
  Size get preferredSize {
    // Note: This is a static getter, but we can't access MediaQuery here.
    // The actual height adjustment is handled in build() by returning a smaller
    // AppBar with custom toolbarHeight when on very small screens.
    return const Size.fromHeight(kToolbarHeight);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantsAsync = ref.watch(availableTenantsProvider);
    final currentTenantId = user?.tenantId;
    final isSmallMobile = MediaQuery.of(context).size.width < 375;
    final toolbarHeight = isSmallMobile ? 48.0 : kToolbarHeight;

    return AppBar(
      toolbarHeight: toolbarHeight,
      leading: IconButton(
        tooltip: 'القائمة',
        onPressed: onOpenDrawer,
        icon: const Icon(Icons.menu),
      ),
      title: const Text('حصاد'),
      centerTitle: true,
      titleTextStyle: isSmallMobile
          ? Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 16)
          : null,
      actions: [
        tenantsAsync.when(
          data: (tenants) {
            if (user == null || tenants.length <= 1) {
              return const SizedBox.shrink();
            }
            final current = tenants.firstWhere(
              (t) => t.id == currentTenantId,
              orElse: () => tenants.first,
            );
            return PopupMenuButton<String>(
              tooltip: 'تبديل المنشأة',
              onSelected: (tenantId) {
                ref.read(tenantSwitchProvider.notifier).switchTo(tenantId);
              },
              itemBuilder: (_) => tenants
                  .map(
                    (t) => PopupMenuItem<String>(
                      value: t.id,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(
                            child: Text(
                              t.name,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontWeight: t.id == current.id
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _roleColor(t.role).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _roleLabel(t.role),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _roleColor(t.role),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FaIcon(FontAwesomeIcons.building, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      current.name,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const FaIcon(FontAwesomeIcons.chevronDown, size: 12),
                ],
              ),
            );
          },
          loading: () => const SizedBox(
            width: 24,
            height: 24,
            child: Center(child: AppProgress(strokeWidth: 2)),
          ),
          error: (_, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Color _roleColor(AppRole role) {
    switch (role) {
      case AppRole.admin:
        return AppColors.danger;
      case AppRole.accountant:
        return AppColors.primary;
      case AppRole.sales:
        return AppColors.success;
      default:
        return AppColors.sidebarText;
    }
  }

  String _roleLabel(AppRole role) {
    switch (role) {
      case AppRole.admin:
        return 'مسؤول';
      case AppRole.accountant:
        return 'محاسب';
      case AppRole.sales:
        return 'مبيعات';
      default:
        return role.dbValue;
    }
  }
}

class _OnboardingBanner extends StatelessWidget {
  const _OnboardingBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.warning,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: const Text(
        'حسابك غير مرتبط بمؤسسة بعد — الرجاء التسجيل أو التواصل مع الإدارة',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }
}
