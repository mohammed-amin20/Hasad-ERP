import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../domain/employees/employee.dart';
import '../../../domain/employees/employee_draft.dart';
import '../../providers/employees_providers.dart';

class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key});

  @override
  ConsumerState<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends ConsumerState<EmployeesScreen> {
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
      ref.read(employeeSearchProvider.notifier).update('');
    }
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(employeesListProvider);

    return PageScaffold(
      title: 'الموظفون',
      subtitle: 'بيانات الموظفين والرواتب الأساسية',
      actions: [
        IconButton(
          tooltip: _searchOpen ? 'إغلاق البحث' : 'بحث',
          onPressed: _toggleSearch,
          icon: Icon(_searchOpen ? Icons.close : Icons.search),
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
                        ref.read(employeeSearchProvider.notifier).update(v),
                    decoration: InputDecoration(
                      hintText: 'بحث بالاسم أو رقم الهاتف...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchCtrl.clear();
                                ref
                                    .read(employeeSearchProvider.notifier)
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
                  data: (employees) {
                    if (employees.isEmpty) {
                      return const _EmptyState();
                    }
                    return _EmployeeList(employees: employees);
                  },
                ),
              ),
            ],
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: FloatingActionButton(
              heroTag: 'employees_add',
              onPressed: () => _showEmployeeForm(context),
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }

  void _showEmployeeForm(BuildContext context, {Employee? employee}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EmployeeFormSheet(
        employee: employee,
        onSave: (draft) async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            final notifier = ref.read(employeesListProvider.notifier);
            if (employee == null) {
              await notifier.create(draft);
            } else {
              await notifier.updateEmployee(id: employee.id, draft: draft);
            }
            if (context.mounted) Navigator.of(context).pop();
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  employee == null ? 'تمت إضافة الموظف' : 'تم تعديل الموظف',
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

class _EmployeeList extends StatelessWidget {
  const _EmployeeList({required this.employees});

  final List<Employee> employees;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: employees.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final e = employees[index];
        return _EmployeeTile(
          employee: e,
          onEdit: () {
            final screen =
                context.findAncestorStateOfType<_EmployeesScreenState>();
            screen?._showEmployeeForm(context, employee: e);
          },
          onDelete: () => _confirmDelete(context, e),
        );
      },
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  const _EmployeeTile({
    required this.employee,
    required this.onEdit,
    required this.onDelete,
  });

  final Employee employee;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.secondary.withValues(alpha: 0.1),
        child: Text(
          employee.name.isNotEmpty ? employee.name[0] : '?',
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.secondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(
        employee.name,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (employee.jobTitle != null && employee.jobTitle!.isNotEmpty)
            Text(employee.jobTitle!, style: theme.textTheme.bodySmall),
          if (employee.phone != null && employee.phone!.isNotEmpty)
            Text(employee.phone!, style: theme.textTheme.bodySmall),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'الراتب الأساسي: ${Money.format(employee.baseSalary)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'edit') onEdit();
          if (v == 'delete') onDelete();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('تعديل')),
          PopupMenuItem(value: 'delete', child: Text('حذف')),
        ],
      ),
    );
  }
}

class _EmployeeFormSheet extends StatefulWidget {
  const _EmployeeFormSheet({required this.onSave, this.employee});

  final Future<void> Function(EmployeeDraft draft) onSave;
  final Employee? employee;

  @override
  State<_EmployeeFormSheet> createState() => _EmployeeFormSheetState();
}

class _EmployeeFormSheetState extends State<_EmployeeFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _jobTitleCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _salaryCtrl;
  bool _submitting = false;

  bool get _isEditing => widget.employee != null;

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _jobTitleCtrl = TextEditingController(text: e?.jobTitle ?? '');
    _phoneCtrl = TextEditingController(text: e?.phone ?? '');
    _salaryCtrl = TextEditingController(
      text: e == null ? '' : Money.editable(e.baseSalary),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _jobTitleCtrl.dispose();
    _phoneCtrl.dispose();
    _salaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final salaryText = _salaryCtrl.text.trim();
    final salary = double.tryParse(salaryText);
    if (salary == null || salary < 0) {
      _showError('أدخل راتباً صحيحاً غير سالب');
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.onSave(
        EmployeeDraft(
          name: _nameCtrl.text.trim(),
          jobTitle: _jobTitleCtrl.text.trim().isEmpty
              ? null
              : _jobTitleCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          baseSalary: Money.fromAmount(salary),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppColors.danger, content: Text(message)),
    );
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
              Text(
                _isEditing ? 'تعديل الموظف' : 'إضافة موظف جديد',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'اسم الموظف',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'أدخل اسم الموظف' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _jobTitleCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'المسمى الوظيفي',
                  prefixIcon: Icon(Icons.work_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _salaryCtrl,
                textInputAction: TextInputAction.done,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'الراتب الأساسي',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                validator: (v) {
                  final text = (v ?? '').trim();
                  if (text.isEmpty) return 'أدخل الراتب الأساسي';
                  final value = double.tryParse(text);
                  if (value == null || value < 0) return 'راتب غير صالح';
                  return null;
                },
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
      ),
    );
  }
}

void _confirmDelete(BuildContext context, Employee employee) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('حذف الموظف'),
      content: Text('هل تريد حذف "${employee.name}" نهائياً؟'),
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
                  .read(employeesListProvider.notifier)
                  .delete(employee.id);
              messenger.showSnackBar(
                const SnackBar(content: Text('تم حذف الموظف')),
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
            Icon(
              Icons.person_outline,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'لا يوجد موظفون',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'اضغط على + لإضافة أول موظف',
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
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
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