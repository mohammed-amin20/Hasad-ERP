import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_progress.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/hasad_card.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../domain/employees/employee.dart';
import '../../../domain/employees/employee_draft.dart';
import '../../providers/employees_providers.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/record_table.dart';
import 'employee_statement_screen.dart';

class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key});

  @override
  ConsumerState<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends ConsumerState<EmployeesScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openStatement(Employee employee) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EmployeeStatementScreen(
          employeeId: employee.id,
          employeeName: employee.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(employeesListProvider);

    return PageScaffold(
      title: 'الموظفون',
      subtitle: 'بيانات الموظفين والرواتب الأساسية',
      child: Stack(
        children: [
          Column(
            children: [
              FilterBar(
                searchController: _searchCtrl,
                hintText: 'بحث بالاسم أو رقم الهاتف...',
                onSearchChanged: (value) =>
                    ref.read(employeeSearchProvider.notifier).update(value),
                onClearSearch: () {
                  _searchCtrl.clear();
                  ref.read(employeeSearchProvider.notifier).update('');
                  setState(() {});
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: AsyncSection<List<Employee>>(
                  value: listAsync,
                  onRetry: () => ref.invalidate(employeesListProvider),
                  emptyIcon: FontAwesomeIcons.userPlus,
                  emptyTitle: 'لا يوجد موظفون',
                  emptyMessage: 'اضغط على زر الإضافة لتسجيل أول موظف.',
                  emptyAction: FilledButton.icon(
                    onPressed: () => _showEmployeeForm(context),
                    icon: const FaIcon(FontAwesomeIcons.plus, size: 13),
                    iconAlignment: IconAlignment.end,
                    label: const Text('إضافة موظف'),
                  ),
                  builder: (context, employees) => RecordTable<Employee>(
                    items: employees,
                    onTap: (e) => _openStatement(e),
                    columns: [
                      RecordColumn<Employee>(
                        label: 'الموظف',
                        primary: true,
                        flex: 3,
                        cell: (context, e) => Row(
                          children: [
                            IconChip(
                              icon: FontAwesomeIcons.user,
                              color: AppColors.secondary,
                              size: 32,
                              iconSize: 13,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    e.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (e.jobTitle?.isNotEmpty == true)
                                    Text(
                                      e.jobTitle!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      RecordColumn<Employee>(
                        label: 'الهاتف',
                        flex: 2,
                        cell: (context, e) => Text(
                          e.phone?.isNotEmpty == true ? e.phone! : '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      RecordColumn<Employee>(
                        label: 'الراتب الأساسي',
                        flex: 2,
                        emphasis: true,
                        alignment: AlignmentDirectional.centerEnd,
                        cell: (context, e) => Text(
                          Money.format(e.baseSalary),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.secondary,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                    trailing: (context, e) => PopupMenuButton<String>(
                      tooltip: 'إجراءات الموظف',
                      onSelected: (value) {
                        if (value == 'statement') _openStatement(e);
                        if (value == 'edit') {
                          _showEmployeeForm(context, employee: e);
                        }
                        if (value == 'delete') _confirmDelete(e);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'statement',
                          child: Text('كشف الحركة'),
                        ),
                        PopupMenuItem(value: 'edit', child: Text('تعديل')),
                        PopupMenuItem(value: 'delete', child: Text('حذف')),
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
              heroTag: 'employees_add',
              tooltip: 'إضافة موظف',
              onPressed: () => _showEmployeeForm(context),
              child: const FaIcon(FontAwesomeIcons.plus),
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

  Future<void> _confirmDelete(Employee employee) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'حذف الموظف',
      message: 'هل تريد حذف "${employee.name}" نهائياً؟',
      confirmLabel: 'حذف',
      tone: ConfirmTone.danger,
    );
    if (!confirmed || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(employeesListProvider.notifier).delete(employee.id);
      messenger.showSnackBar(const SnackBar(content: Text('تم حذف الموظف')));
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text(mapErrorToAppException(error).message),
        ),
      );
    }
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
              Row(
                children: [
                  const IconChip(
                    icon: FontAwesomeIcons.userTie,
                    color: AppColors.secondary,
                    size: 40,
                    iconSize: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isEditing ? 'تعديل الموظف' : 'إضافة موظف جديد',
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
                  labelText: 'اسم الموظف',
                  prefixIcon: FaIcon(FontAwesomeIcons.user),
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
                  prefixIcon: FaIcon(FontAwesomeIcons.briefcase),
                ),
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
                controller: _salaryCtrl,
                textInputAction: TextInputAction.done,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'الراتب الأساسي',
                  prefixIcon: FaIcon(FontAwesomeIcons.moneyBill),
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
