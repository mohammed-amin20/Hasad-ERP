import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_progress.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/hasad_card.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../domain/customers/customer.dart';
import '../../../domain/customers/customer_draft.dart';
import '../../providers/auth_providers.dart';
import '../../providers/customers_providers.dart';
import '../../providers/reminders_providers.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/record_table.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(customersListProvider);
    final user = ref.watch(authStateProvider).value;

    return PageScaffold(
      title: 'العملاء',
      subtitle: 'إدارة بيانات العملاء وحساباتهم',
      icon: FontAwesomeIcons.users,
      child: Stack(
        children: [
          Column(
            children: [
              FilterBar(
                searchController: _searchCtrl,
                hintText: 'بحث بالاسم أو رقم الهاتف...',
                onSearchChanged: (value) =>
                    ref.read(customerSearchProvider.notifier).update(value),
                onClearSearch: () {
                  _searchCtrl.clear();
                  ref.read(customerSearchProvider.notifier).update('');
                  setState(() {});
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: AsyncSection<List<Customer>>(
                  value: listAsync,
                  onRetry: () => ref.invalidate(customersListProvider),
                  emptyIcon: FontAwesomeIcons.userPlus,
                  emptyTitle: 'لا يوجد عملاء',
                  emptyMessage: 'اضغط على زر الإضافة لتسجيل أول عميل.',
                  emptyAction: FilledButton.icon(
                    onPressed: () => _showCustomerForm(context),
                    icon: const FaIcon(FontAwesomeIcons.plus, size: 13),
                    iconAlignment: IconAlignment.end,
                    label: const Text('إضافة عميل'),
                  ),
                  builder: (context, customers) => RecordTable<Customer>(
                    items: customers,
                    columns: [
                      RecordColumn<Customer>(
                        label: 'العميل',
                        primary: true,
                        flex: 3,
                        cell: (context, c) => Row(
                          children: [
                            IconChip(
                              icon: FontAwesomeIcons.user,
                              color: AppColors.primary,
                              size: 32,
                              iconSize: 13,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                c.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      RecordColumn<Customer>(
                        label: 'الهاتف',
                        flex: 2,
                        cell: (context, c) => Text(
                          c.phone?.isNotEmpty == true ? c.phone! : '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      RecordColumn<Customer>(
                        label: 'ملاحظات',
                        flex: 3,
                        cell: (context, c) => Text(
                          c.notes?.isNotEmpty == true ? c.notes! : '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                    trailing: (context, c) => PopupMenuButton<String>(
                      tooltip: 'إجراءات العميل',
                      onSelected: (value) {
                        if (value == 'remind') _sendReminder(c);
                        if (value == 'edit') {
                          _showCustomerForm(context, customer: c);
                        }
                        if (value == 'delete') _confirmDelete(context, c);
                      },
                      itemBuilder: (_) => [
                        if (user?.isAdmin ?? false)
                          const PopupMenuItem(
                            value: 'remind',
                            child: Text('إرسال تذكير'),
                          ),
                        const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('حذف'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            bottom: 0,
            child: FloatingActionButton(
              heroTag: 'customers_add',
              tooltip: 'إضافة عميل',
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
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const IconChip(
                    icon: FontAwesomeIcons.user,
                    color: AppColors.primary,
                    size: 40,
                    iconSize: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isEditing ? 'تعديل العميل' : 'إضافة عميل جديد',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                autofocus: true,
                autofillHints: const [AutofillHints.name],
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
                autofillHints: const [AutofillHints.telephoneNumber],
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
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: AppProgress(strokeWidth: 2),
                      )
                    : Text(_isEditing ? 'حفظ التعديلات' : 'إضافة'),
              ),
            ],
          ),
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
