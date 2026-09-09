import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= AppConfig.breakpointDesktop;
    final hasSidebar = width >= AppConfig.breakpointNarrow;
    final collapsed = isDesktop ? false : _sidebarCollapsed;

    return ConnectivityListener(
      child: Scaffold(
        body: hasSidebar
            ? Row(
                children: [
                  SideNavigation(
                    collapsed: collapsed,
                    onToggleCollapse: isDesktop
                        ? null
                        : () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                  ),
                  Expanded(child: _ScreenBody(user: user)),
                ],
              )
            : _ScreenBody(user: user),
        drawer: hasSidebar ? null : const SideNavigation(),
      ),
    );
  }
}

class _ScreenBody extends ConsumerWidget {
  const _ScreenBody({required this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(currentDestinationProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < AppConfig.breakpointNarrow;
    final visible = user == null ||
        (index >= 0 &&
            index < appTabs.length &&
            appTabs[index].allowedFor(user!));
    final body = visible && index >= 0 && index < appScreens.length
        ? appScreens[index]
        : const SizedBox.shrink();

    return Scaffold(
      appBar: isMobile ? _MobileAppBar(user: user) : null,
      body: Column(
        children: [
          const OfflineBanner(),
          if (user != null && !user!.hasTenant) const _OnboardingBanner(),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Mobile AppBar with tenant switcher for < 700px.
class _MobileAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _MobileAppBar({required this.user});

  final AppUser? user;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantsAsync = ref.watch(availableTenantsProvider);
    final currentTenantId = user?.tenantId;

    return AppBar(
      title: const Text('حصاد'),
      centerTitle: true,
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
              itemBuilder: (_) => tenants.map((t) => PopupMenuItem<String>(
                value: t.id,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: Text(
                        t.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: t.id == current.id ? FontWeight.w700 : FontWeight.w500,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
              )).toList(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FaIcon(FontAwesomeIcons.building, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      current.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
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
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, __) => const SizedBox.shrink(),
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
        return AppColors.textMuted;
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