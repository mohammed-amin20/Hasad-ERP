import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_progress.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/hasad_card.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/offline/report_keys.dart';
import '../../../domain/accounts/account.dart';
import '../../../domain/accounts/account_draft.dart';
import '../../providers/accounts_providers.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/freshness_chip.dart';
import '../../widgets/record_table.dart';
import '../../widgets/state_views.dart';

class ChartOfAccountsScreen extends ConsumerStatefulWidget {
  const ChartOfAccountsScreen({super.key});

  @override
  ConsumerState<ChartOfAccountsScreen> createState() =>
      _ChartOfAccountsScreenState();
}

class _ChartOfAccountsScreenState extends ConsumerState<ChartOfAccountsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chartAsync = ref.watch(chartOfAccountsProvider);

    return PageScaffold(
      title: 'دليل الحسابات',
      subtitle: 'شجرة الحسابات المحاسبية',
      actions: [
        FreshnessChip(cacheKey: chartOfAccountsKey),
        IconButton(
          tooltip: 'تحديث',
          onPressed: () => ref.invalidate(chartOfAccountsProvider),
          icon: const FaIcon(FontAwesomeIcons.rotate),
        ),
      ],
      child: Stack(
        children: [
          Column(
            children: [
              FilterBar(
                searchController: _searchCtrl,
                hintText: 'بحث بالكود أو الاسم...',
                onSearchChanged: (value) => setState(() => _query = value.trim()),
                onClearSearch: () {
                  _searchCtrl.clear();
                  setState(() => _query = '');
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: AsyncSection<List<Account>>(
                  value: chartAsync,
                  onRetry: () => ref.invalidate(chartOfAccountsProvider),
                  emptyIcon: FontAwesomeIcons.sitemap,
                  emptyTitle: 'لا توجد حسابات',
                  emptyMessage: 'أضف أول حساب لبدء بناء دليل الحسابات.',
                  builder: (context, accounts) {
                    final filtered = _query.isEmpty
                        ? accounts
                        : accounts
                            .where((a) =>
                                a.code.contains(_query) ||
                                a.name.contains(_query))
                            .toList();
                    if (filtered.isEmpty) {
                      return const EmptyStateCard(
                        icon: FontAwesomeIcons.magnifyingGlass,
                        title: 'لا نتائج',
                        message: 'لا يوجد حساب يطابق البحث الحالي.',
                      );
                    }

                    final groups = <AccountType, List<Account>>{};
                    for (final account in filtered) {
                      (groups[account.type] ??= []).add(account);
                    }

                    final sortedAccounts = <Account>[];
                    const typeOrder = [
                      AccountType.asset,
                      AccountType.liability,
                      AccountType.equity,
                      AccountType.revenue,
                      AccountType.expense,
                    ];
                    for (final type in typeOrder) {
                  final list = groups[type];
                  if (list != null && list.isNotEmpty) {
                    sortedAccounts.addAll(list);
                  }
                }

                return RecordTable<Account>(
                      items: sortedAccounts,
                      onTap: (a) => _showAccountForm(context),
                      columns: [
                        RecordColumn<Account>(
                          label: 'الكود',
                          primary: true,
                          flex: 2,
                          cell: (context, a) => Text(
                            a.code,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                        RecordColumn<Account>(
                          label: 'اسم الحساب',
                          flex: 3,
                          cell: (context, a) => Text(
                            a.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        RecordColumn<Account>(
                          label: 'الحساب الأب',
                          flex: 2,
                          cell: (context, a) => Text(
                            a.parentCode ?? '—',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        RecordColumn<Account>(
                          label: 'النوع',
                          flex: 2,
                          cell: (context, a) => StatusBadge(
                            label: a.type.label,
                            palette: _typePalette(a.type),
                          ),
                        ),
                        RecordColumn<Account>(
                          label: 'الرصيد',
                          flex: 2,
                          cell: (context, a) => Text(
                            Money.format(a.balance),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: a.balance < 0
                                  ? AppColors.danger
                                  : AppColors.textPrimary,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ],
                      trailing: (context, a) => const SizedBox.shrink(),
                    );
                  },
                ),
              ),
            ],
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: FloatingActionButton(
              heroTag: 'accounts_add',
              tooltip: 'إضافة حساب',
              onPressed: () => _showAccountForm(context),
              child: const FaIcon(FontAwesomeIcons.plus),
            ),
          ),
        ],
      ),
    );
  }

  static BadgePalette _typePalette(AccountType type) {
    switch (type) {
      case AccountType.asset:
        return BadgePalette.paid;
      case AccountType.liability:
        return BadgePalette.unpaid;
      case AccountType.equity:
        return BadgePalette.partial;
      case AccountType.revenue:
        return BadgePalette.paid;
      case AccountType.expense:
        return BadgePalette.warning;
    }
  }

  void _showAccountForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AccountFormSheet(
        onSave: (draft) async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            final account = await ref
                .read(chartOfAccountsProvider.notifier)
                .create(draft);
            if (context.mounted) Navigator.of(context).pop();
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  'تمت إضافة الحساب ${account.code} — ${account.name}',
                ),
              ),
            );
          } on Object catch (error) {
            messenger.showSnackBar(
              SnackBar(
                backgroundColor: AppColors.danger,
                content: Text(mapErrorToAppException(error).message),
              ),
            );
          }
        },
      ),
    );
  }
}

class _AccountFormSheet extends ConsumerStatefulWidget {
  const _AccountFormSheet({required this.onSave});

  final Future<void> Function(AccountDraft draft) onSave;

  @override
  ConsumerState<_AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends ConsumerState<_AccountFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _parentCtrl = TextEditingController();
  AccountType _type = AccountType.asset;
  bool _submitting = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _parentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await widget.onSave(
        AccountDraft(
          code: _codeCtrl.text.trim(),
          name: _nameCtrl.text.trim(),
          type: _type,
          parentCode: _parentCtrl.text.trim().isEmpty
              ? null
              : _parentCtrl.text.trim(),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPadding),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const IconChip(
                  icon: FontAwesomeIcons.sitemap,
                  color: AppColors.primary,
                  size: 40,
                  iconSize: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'إضافة حساب جديد',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'أدخل بيانات الحساب الجديد',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _codeCtrl,
              autofocus: true,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
              ],
              decoration: const InputDecoration(
                labelText: 'كود الحساب',
                hintText: 'مثال: 5228',
                prefixIcon: FaIcon(FontAwesomeIcons.hashtag),
              ),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'أدخل كود الحساب' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'اسم الحساب',
                prefixIcon: FaIcon(FontAwesomeIcons.heading),
              ),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'أدخل اسم الحساب' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AccountType>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'نوع الحساب',
                prefixIcon: FaIcon(FontAwesomeIcons.layerGroup),
              ),
              items: const [
                DropdownMenuItem(value: AccountType.asset, child: Text('أصول')),
                DropdownMenuItem(
                  value: AccountType.liability,
                  child: Text('خصوم'),
                ),
                DropdownMenuItem(
                  value: AccountType.equity,
                  child: Text('حقوق ملكية'),
                ),
                DropdownMenuItem(
                  value: AccountType.revenue,
                  child: Text('إيرادات'),
                ),
                DropdownMenuItem(
                  value: AccountType.expense,
                  child: Text('مصاريف'),
                ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _type = v);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _parentCtrl,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'كود الحساب الأب (اختياري)',
                prefixIcon: FaIcon(FontAwesomeIcons.sitemap),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          AppProgress(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }
}