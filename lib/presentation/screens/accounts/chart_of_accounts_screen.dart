import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_progress.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../domain/accounts/account.dart';
import '../../../domain/accounts/account_draft.dart';
import '../../providers/accounts_providers.dart';

class ChartOfAccountsScreen extends ConsumerStatefulWidget {
  const ChartOfAccountsScreen({super.key});

  @override
  ConsumerState<ChartOfAccountsScreen> createState() =>
      _ChartOfAccountsScreenState();
}

class _ChartOfAccountsScreenState extends ConsumerState<ChartOfAccountsScreen> {
  static const _typeOrder = [
    AccountType.asset,
    AccountType.liability,
    AccountType.equity,
    AccountType.revenue,
    AccountType.expense,
  ];

  @override
  Widget build(BuildContext context) {
    final chartAsync = ref.watch(chartOfAccountsProvider);

    return PageScaffold(
      title: 'دليل الحسابات',
      subtitle: 'شجرة الحسابات المحاسبية',
      actions: [
        IconButton(
          tooltip: 'تحديث',
          onPressed: () => ref.invalidate(chartOfAccountsProvider),
          icon: const FaIcon(FontAwesomeIcons.rotate),
        ),
      ],
      child: Stack(
        children: [
          chartAsync.when(
            loading: () => const Center(child: AppProgress()),
            error: (e, _) => _ErrorState(message: e.toString()),
            data: (accounts) {
              if (accounts.isEmpty) return const _EmptyState();
              return _GroupedList(accounts: accounts, typeOrder: _typeOrder);
            },
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

class _GroupedList extends StatelessWidget {
  const _GroupedList({required this.accounts, required this.typeOrder});

  final List<Account> accounts;
  final List<AccountType> typeOrder;

  @override
  Widget build(BuildContext context) {
    final groups = <AccountType, List<Account>>{};
    for (final account in accounts) {
      (groups[account.type] ??= []).add(account);
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        for (final type in typeOrder)
          if (groups[type]?.isNotEmpty ?? false) ...[
            _TypeHeader(type: type, count: groups[type]!.length),
            for (final account in groups[type]!) _AccountTile(account: account),
            const SizedBox(height: 16),
          ],
      ],
    );
  }
}

class _TypeHeader extends StatelessWidget {
  const _TypeHeader({required this.type, required this.count});

  final AccountType type;
  final int count;

  static const _typeColors = {
    AccountType.asset: AppColors.success,
    AccountType.liability: AppColors.danger,
    AccountType.equity: AppColors.secondary,
    AccountType.revenue: AppColors.primary,
    AccountType.expense: AppColors.warning,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _typeColors[type] ?? AppColors.textMuted;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            type.label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '($count)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final balance = account.balance;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              account.code,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  account.parentCode ?? account.type.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            Money.format(balance),
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: balance < 0 ? AppColors.danger : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountFormSheet extends StatefulWidget {
  const _AccountFormSheet({required this.onSave});

  final Future<void> Function(AccountDraft draft) onSave;

  @override
  State<_AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends State<_AccountFormSheet> {
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
            Text(
              'إضافة حساب جديد',
              style: Theme.of(context).textTheme.titleMedium,
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
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: AppProgress(strokeWidth: 2),
                    )
                  : const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FaIcon(
              FontAwesomeIcons.sitemap,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد حسابات',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FaIcon(
              FontAwesomeIcons.circleExclamation,
              size: 48,
              color: AppColors.danger,
            ),
            const SizedBox(height: 16),
            Text('حدث خطأ', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
