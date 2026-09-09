import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../domain/customers/customer.dart';
import '../../../domain/customers/customer_draft.dart';
import '../../providers/auth_providers.dart';
import '../../providers/customers_providers.dart';
import '../../providers/reminders_providers.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _searchCtrl = TextEditingController();
  bool _searchOpen = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() => _searchOpen = !_searchOpen);
    if (!_searchOpen) {
      _searchCtrl.clear();
      ref.read(customerSearchProvider.notifier).update('');
    }
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(customersListProvider);
    final user = ref.watch(authStateProvider).value;

    return PageScaffold(
      title: 'العملاء',
      subtitle: 'إدارة بيانات العملاء وحساباتهم',
      actions: [
        IconButton(
          tooltip: _searchOpen ? 'إغلاق البحث' : 'بحث',
          onPressed: _toggleSearch,
          icon: FaIcon(_searchOpen ? FontAwesomeIcons.xmark : FontAwesomeIcons.magnifyingGlass),
        ),
      ],
      child: Stack(
        children: [
          Column(
            children: [
              if (_searchOpen)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onChanged: (v) =>
                        ref.read(customerSearchProvider.notifier).update(v),
                    decoration: InputDecoration(
                      hintText: 'بحث بالاسم أو رقم الهاتف...',
                      prefixIcon: const FaIcon(FontAwesomeIcons.magnifyingGlass),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const FaIcon(FontAwesomeIcons.xmark),
                              onPressed: () {
                                _searchCtrl.clear();
                                ref
                                    .read(customerSearchProvider.notifier)
                                    .update('');
                              },
                            )
                          : null,
                    ),
                  ),
                ),
              Expanded(
                child: listAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _ErrorState(message: e.toString()),
                  data: (customers) {
                    if (customers.isEmpty) {
                      return const _EmptyState();
                    }
                    return _CustomerList(
                      customers: customers,
                      canRemind: user?.isAdmin ?? false,
                      onRemind: _sendReminder,
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
              heroTag: 'customers_add',
              onPressed: () => _showCustomerForm(context),
              child: const FaIcon(FontAwesomeIcons.plus),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendReminder(Customer customer) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(reminderRepositoryProvider).sendReminderNow(customer.id);
      messenger.showSnackBar(
        SnackBar(content: Text('تم إرسال تذكير إلى "${customer.name}"')),
      );
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text(mapErrorToAppException(error).message),
        ),
      );
    }
  }

  void _showCustomerForm(BuildContext context, {Customer? customer}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CustomerFormSheet(
        customer: customer,
        onSave: (draft) async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            final notifier = ref.read(customersListProvider.notifier);
            if (customer == null) {
              await notifier.create(draft);
            } else {
              await notifier.updateCustomer(id: customer.id, draft: draft);
            }
            if (context.mounted) Navigator.of(context).pop();
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  customer == null ? 'تمت إضافة العميل' : 'تم تعديل العميل',
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

class _CustomerList extends StatelessWidget {
  const _CustomerList({
    required this.customers,
    required this.canRemind,
    required this.onRemind,
  });

  final List<Customer> customers;
  final bool canRemind;
  final void Function(Customer customer) onRemind;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: customers.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final c = customers[index];
        return _CustomerTile(
          customer: c,
          canRemind: canRemind,
          onRemind: () => onRemind(c),
          onEdit: () {
            final screen =
                context.findAncestorStateOfType<_CustomersScreenState>();
            screen?._showCustomerForm(context, customer: c);
          },
          onDelete: () => _confirmDelete(context, c),
        );
      },
    );
  }
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({
    required this.customer,
    required this.canRemind,
    required this.onRemind,
    required this.onEdit,
    required this.onDelete,
  });

  final Customer customer;
  final bool canRemind;
  final VoidCallback onRemind;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
        child: Text(
          customer.name.isNotEmpty ? customer.name[0] : '?',
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(
        customer.name,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: customer.phone != null && customer.phone!.isNotEmpty
          ? Text(customer.phone!, style: theme.textTheme.bodySmall)
          : null,
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'remind') onRemind();
          if (v == 'edit') onEdit();
          if (v == 'delete') onDelete();
        },
        itemBuilder: (_) => [
          if (canRemind)
            const PopupMenuItem(value: 'remind', child: Text('إرسال تذكير')),
          const PopupMenuItem(value: 'edit', child: Text('تعديل')),
          const PopupMenuItem(value: 'delete', child: Text('حذف')),
        ],
      ),
    );
  }
}

class _CustomerFormSheet extends StatefulWidget {
  const _CustomerFormSheet({required this.onSave, this.customer});

  final Future<void> Function(CustomerDraft draft) onSave;
  final Customer? customer;

  @override
  State<_CustomerFormSheet> createState() => _CustomerFormSheetState();
}

class _CustomerFormSheetState extends State<_CustomerFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _notesCtrl;
  bool _submitting = false;

  bool get _isEditing => widget.customer != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.customer?.name ?? '');
    _phoneCtrl = TextEditingController(text: widget.customer?.phone ?? '');
    _notesCtrl = TextEditingController(text: widget.customer?.notes ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await widget.onSave(
        CustomerDraft(
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty
              ? null
              : _phoneCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty
              ? null
              : _notesCtrl.text.trim(),
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
              _isEditing ? 'تعديل العميل' : 'إضافة عميل جديد',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameCtrl,
              textInputAction: TextInputAction.next,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'اسم العميل',
                prefixIcon: FaIcon(FontAwesomeIcons.user),
              ),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'أدخل اسم العميل' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف',
                prefixIcon: FaIcon(FontAwesomeIcons.phone),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              textInputAction: TextInputAction.done,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'ملاحظات',
                prefixIcon: FaIcon(FontAwesomeIcons.fileLines),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? 'حفظ التعديلات' : 'إضافة'),
            ),
          ],
        ),
      ),
    );
  }
}

void _confirmDelete(BuildContext context, Customer customer) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('حذف العميل'),
      content: Text('هل تريد حذف "${customer.name}" نهائياً؟'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () async {
            final navigator = Navigator.of(context);
            final messenger = ScaffoldMessenger.of(context);
            final container = ProviderScope.containerOf(context);
            navigator.pop();
            try {
              await container
                  .read(customersListProvider.notifier)
                  .delete(customer.id);
              messenger.showSnackBar(
                const SnackBar(content: Text('تم حذف العميل')),
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
          child: const Text('حذف'),
        ),
      ],
    ),
  );
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
            FaIcon(FontAwesomeIcons.userPlus,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text('لا يوجد عملاء', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'اضغط على + لإضافة أول عميل',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
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
            const FaIcon(FontAwesomeIcons.circleExclamation, size: 48, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(
              'حدث خطأ',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}