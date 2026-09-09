import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
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
    final visible = user == null ||
        (index >= 0 &&
            index < appTabs.length &&
            appTabs[index].allowedFor(user!));
    final body = visible && index >= 0 && index < appScreens.length
        ? appScreens[index]
        : const SizedBox.shrink();

    return Column(
      children: [
        const OfflineBanner(),
        if (user != null && !user!.hasTenant) const _OnboardingBanner(),
        Expanded(child: body),
      ],
    );
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