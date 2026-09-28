import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_progress.dart';
import '../../core/accessibility/reduced_motion.dart';
import '../../core/config/app_config.dart';
import '../../core/error/app_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand_logo.dart';
import '../../data/offline/local_store.dart';
import '../../domain/auth/app_role.dart';
import '../../domain/auth/tenant_ref.dart';
import '../providers/auth_providers.dart';
import '../providers/navigation_providers.dart';
import '../providers/offline_providers.dart';
import '../widgets/confirm_dialog.dart';
import 'app_tabs.dart';

/// Sidebar content shared by the fixed/collapsible sidebar and the drawer.
///
/// Matches the reference HTML sidebar: a vertical navy gradient, the brand
/// header, role-aware grouped categories with small uppercase labels, and a
/// footer row with the user + sign-out + version tag.
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
    final visible = visibleTabs.toSet();

    void select(int index) {
      ref.read(currentDestinationProvider.notifier).select(index);
      Navigator.of(context).maybePop();
    }

    Widget item(int index) => _NavItem(
      tab: appTabs[index],
      collapsed: collapsed,
      active: selected == index,
      onTap: () => select(index),
    );

    final navChildren = <Widget>[
      // Standalone dashboard item (index 0), like the reference sidebar.
      if (visible.contains(0)) item(0),
    ];
    for (final category in sidebarCategories) {
      final group = category.indices.where(visible.contains).toList();
      if (group.isEmpty) continue;
      if (!collapsed) navChildren.add(_CategoryHeader(title: category.title));
      navChildren.addAll(group.map(item));
    }

    return Container(
      width: collapsed
          ? AppConfig.sidebarCollapsedWidth
          : AppConfig.sidebarExpandedWidth,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F172A), Color(0xFF121E33)],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(3, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _Header(collapsed: collapsed, onToggleCollapse: onToggleCollapse),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: navChildren,
            ),
          ),
          _SidebarFooter(collapsed: collapsed),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.collapsed, this.onToggleCollapse});

  final bool collapsed;
  final VoidCallback? onToggleCollapse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final tenantsAsync = ref.watch(availableTenantsProvider);
    final showLabel = !collapsed;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand row
          showLabel
              ? Row(
                  children: [
                    const BrandLogo(size: 32, variant: BrandMarkVariant.amber),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppConfig.appName,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          Text(
                            'نظام إدارة المؤسسات',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: AppColors.sidebarText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onToggleCollapse != null)
                      IconButton(
                        onPressed: onToggleCollapse,
                        tooltip: 'طي القائمة',
                        color: AppColors.sidebarText,
                        icon: const FaIcon(
                          FontAwesomeIcons.chevronLeft,
                          size: 15,
                        ),
                      ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: onToggleCollapse == null
                          ? const SizedBox.shrink()
                          : IconButton(
                              onPressed: onToggleCollapse,
                              tooltip: 'توسيع القائمة',
                              color: AppColors.sidebarText,
                              icon: const FaIcon(
                                FontAwesomeIcons.chevronRight,
                                size: 15,
                              ),
                            ),
                    ),
                  ],
                ),
          // Tenant switcher (only show if user has multiple tenants)
          if (showLabel) ...[
            const SizedBox(height: 12),
            tenantsAsync.when(
              data: (tenants) {
                if (user == null || tenants.length <= 1) {
                  return const SizedBox.shrink();
                }
                final currentTenantId = user.tenantId;
                final current = tenants.firstWhere(
                  (t) => t.id == currentTenantId,
                  orElse: () => tenants.first,
                );
                return _TenantSwitcher(
                  current: current,
                  tenants: tenants,
                  onSwitch: (tenantId) {
                    ref.read(tenantSwitchProvider.notifier).switchTo(tenantId);
                  },
                );
              },
              loading: () => const SizedBox(
                height: 36,
                child: Center(child: AppProgress(strokeWidth: 2)),
              ),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tenant switcher widget for the sidebar header.
class _TenantSwitcher extends StatelessWidget {
  const _TenantSwitcher({
    required this.current,
    required this.tenants,
    required this.onSwitch,
  });

  final TenantRef current;
  final List<TenantRef> tenants;
  final void Function(String tenantId) onSwitch;

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

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x14FFFFFF),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {},
        child: PopupMenuButton<String>(
          tooltip: 'تبديل المنشأة',
          onSelected: onSwitch,
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
              const FaIcon(
                FontAwesomeIcons.building,
                size: 18,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  current.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              const FaIcon(
                FontAwesomeIcons.chevronDown,
                size: 12,
                color: AppColors.sidebarText,
              ),
            ],
          ),
        ),
      ),
    );
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

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: AppColors.sidebarText,
        ),
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
    final color = active
        ? Colors.white
        : (tab.iconColor ?? AppColors.sidebarText);
    return Semantics(
      selected: active,
      label: tab.title,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: active
              ? Colors.transparent
              : Colors.white.withValues(alpha: 0.06),
          child: AnimatedContainer(
            duration: motionDuration(
              context,
              const Duration(milliseconds: 180),
            ),
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: active
                  ? const LinearGradient(
                      colors: [
                        Color(0x472563EB),
                        Color(0x1F2563EB),
                        Colors.transparent,
                      ],
                      stops: [0, 0.55, 1],
                    )
                  : null,
            ),
            child: Stack(
              alignment: AlignmentDirectional.centerStart,
              children: [
                if (active)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Container(
                      width: 3,
                      height: 26,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                Row(
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
                          style: AppTheme.light.textTheme.bodyLarge?.copyWith(
                            color: color,
                            fontSize: 13.5,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarFooter extends ConsumerWidget {
  const _SidebarFooter({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final raw = (user?.name ?? user?.email ?? '').trim();
    final initials = raw.isEmpty ? '؟' : raw[0];
    final showLabel = !collapsed;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        collapsed ? 6 : 14,
        10,
        collapsed ? 6 : 14,
        12,
      ),
      decoration: const BoxDecoration(
        color: Color(0x05FFFFFF),
        border: Border(top: BorderSide(color: Color(0x0FFFFFFF))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: collapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.spaceBetween,
            children: [
              if (showLabel)
                Expanded(
                  child: _UserLabel(initials: initials, name: raw),
                ),
              _LogoutButton(),
            ],
          ),
          if (showLabel) ...[
            const SizedBox(height: 8),
            Text(
              AppConfig.appFooterNote,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.sidebarText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _UserLabel extends StatelessWidget {
  const _UserLabel({required this.initials, required this.name});

  final String initials;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            initials,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.light.textTheme.bodySmall?.copyWith(
              color: AppColors.sidebarText,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _LogoutButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Tooltip(
      message: 'تسجيل الخروج',
      child: Material(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          hoverColor: AppColors.danger,
          onTap: () => signOutAndWipeLocalData(context, ref),
          child: const SizedBox(
            width: 40,
            height: 40,
            child: FaIcon(
              FontAwesomeIcons.powerOff,
              color: AppColors.sidebarText,
              size: 14,
            ),
          ),
        ),
      ),
    );
  }
}

/// Signs the user out, first wiping that workspace's offline data from the
/// device.
///
/// A shared tablet is the reason this exists: a tenant's invoices, customers
/// and stock sit in sqlite, and a sign-out that left them behind hands the next
/// person the previous workspace's data.
///
/// The rule is that **sign-out always succeeds**. It is the one action a user
/// must never be locked out of, so a stuck queue can never refuse it — if the
/// count cannot be read, or the wipe throws, the sign-out proceeds anyway and
/// the error is surfaced. Blocking sign-out to protect unsynced writes would
/// mean a user with a permanently-failing queue could never sign out at all.
///
/// Pending work is never discarded silently. When queued legs exist the user
/// is told exactly how many, and told plainly that continuing deletes them from
/// this device with no way to recover them client-side. Choosing to continue is
/// an informed decision, not an accident.
Future<void> signOutAndWipeLocalData(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final store = ref.read(localStoreProvider).value;
  final tenantId = ref.read(currentTenantIdProvider);

  // The wipe is attempted in its own scope so a failure cannot abort the
  // sign-out. Sharing one try-block here was a real defect: `clearTenant`
  // throwing skipped the `signOut()` below entirely, which is the lockout this
  // function exists to prevent.
  String? wipeFailure;
  try {
    if (store != null && tenantId != null && tenantId.isNotEmpty) {
      final pending = await store.pendingCount(tenantId);
      // Only a genuine "keep working" answer aborts. A `null` mount is not a
      // veto — the user is already gone from this screen, so the sign-out
      // proceeds and the data is still cleared.
      if (pending > 0 && context.mounted) {
        final confirmed = await showConfirmDialog(
          context,
          title: 'تسجيل الخروج مع وجود عمليات غير مزامنة',
          message: 'يوجد $pending عملية غير مزامنة على هذا الجهاز.\n'
              'سيؤدي تسجيل الخروج إلى حذفها نهائياً من الجهاز،'
              ' ولا يمكن استعادتها بعد ذلك.\n'
              'هل تريد المتابعة؟',
          confirmLabel: 'خروج وحذف',
          cancelLabel: 'إلغاء',
          icon: FontAwesomeIcons.triangleExclamation,
          tone: ConfirmTone.danger,
        );
        if (!confirmed) return;
      }

      // `force: true` is correct here precisely because the user just confirmed
      // (or had nothing pending). A refusal is impossible because there is
      // nothing left to refuse.
      await store.clearTenant(tenantId, force: true);
    }
  } on Object catch (error) {
    wipeFailure = mapErrorToAppException(error).message;
  }

  try {
    final repo = await ref.read(authRepositoryProvider.future);
    await repo.signOut();
  } on Object catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(mapErrorToAppException(error).message)));
  }

  // A failed wipe is reported only after the sign-out, so the user is not left
  // staring at an error on a screen they have already been routed off.
  if (wipeFailure != null) {
    messenger.showSnackBar(SnackBar(content: Text(wipeFailure)));
  }
}
