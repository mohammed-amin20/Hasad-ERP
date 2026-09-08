import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../domain/employees/employee.dart';
import '../../../domain/salaries/salary_repository.dart';
import '../../providers/employees_providers.dart';
import '../../providers/salaries_providers.dart';
import '../../widgets/salary_sheets.dart';

class SalariesScreen extends ConsumerStatefulWidget {
  const SalariesScreen({super.key});

  @override
  ConsumerState<SalariesScreen> createState() => _SalariesScreenState();
}

class _SalariesScreenState extends ConsumerState<SalariesScreen> {
  String? _employeeId;
  DateTime _month = firstOfMonth(DateTime.now());

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _month = firstOfMonth(picked));
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(allEmployeesProvider);
    final selectedId = _employeeId;

    return PageScaffold(
      title: 'الرواتب',
      subtitle: 'الاستحقاقات والخصومات ودفع الرواتب',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          employeesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _InlineError(message: e.toString()),
            data: (employees) => _buildControls(context, employees),
          ),
          const SizedBox(height: 16),
          if (selectedId != null)
            Expanded(
              child: ref
                  .watch(salaryRunProvider(selectedId, _month))
                  .when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (e, _) => _ErrorState(message: e.toString()),
                    data: (ent) => _buildRun(
                      context,
                      ent,
                      employeesAsync.value ?? const [],
                    ),
                  ),
            )
          else
            const Expanded(child: _HintState()),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context, List<Employee> employees) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String?>(
          initialValue: _employeeId,
          decoration: const InputDecoration(
            labelText: 'الموظف',
            prefixIcon: FaIcon(FontAwesomeIcons.user),
          ),
          hint: const Text('اختر موظفاً...'),
          items: [
            for (final e in employees)
              DropdownMenuItem(value: e.id, child: Text(e.name)),
          ],
          onChanged: (v) => setState(() => _employeeId = v),
        ),
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _pickMonth,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'الشهر',
              prefixIcon: FaIcon(FontAwesomeIcons.calendarDay),
            ),
            child: Text(
              '${_month.year}/${_month.month.toString().padLeft(2, '0')}',
              style: theme.textTheme.bodyLarge,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRun(
    BuildContext context,
    EmployeeEntitlement ent,
    List<Employee> employees,
  ) {
    final theme = Theme.of(context);
    final canPay = ent.netDue > 0;
    var name = '';
    for (final e in employees) {
      if (e.id == ent.employeeId) name = e.name;
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _EntitlementRow(
                  label: 'الراتب الأساسي',
                  value: ent.baseSalary,
                ),
                const SizedBox(height: 8),
                _EntitlementRow(
                  label: 'متأخرات سابقة',
                  value: ent.arrears,
                ),
                const SizedBox(height: 8),
                _EntitlementRow(
                  label: 'إضافات',
                  value: ent.entitlements,
                  color: AppColors.success,
                ),
                const SizedBox(height: 8),
                _EntitlementRow(
                  label: 'خصومات',
                  value: ent.deductions,
                  color: AppColors.danger,
                ),
                const Divider(height: 24),
                _EntitlementRow(
                  label: 'صافي المستحقات',
                  value: ent.netDue,
                  emphasized: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => showAddMovementSheet(
                  context,
                  employeeId: ent.employeeId,
                  employeeName: name,
                  month: _month,
                ),
                icon: const FaIcon(FontAwesomeIcons.arrowsUpDown),
                label: const Text('تسجيل حركة'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: canPay
                    ? () => showPaySalarySheet(
                          context,
                          employeeId: ent.employeeId,
                          employeeName: name,
                          month: _month,
                          entitlement: ent,
                        )
                    : null,
                icon: const FaIcon(FontAwesomeIcons.moneyBill),
                label: const Text('صرف الراتب'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('سجل الصرف', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        _SalaryHistoryList(employeeId: ent.employeeId),
      ],
    );
  }
}

class _EntitlementRow extends StatelessWidget {
  const _EntitlementRow({
    required this.label,
    required this.value,
    this.color,
    this.emphasized = false,
  });

  final String label;
  final int value;
  final Color? color;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = emphasized
        ? theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          )
        : theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          );
    return Row(
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        const Spacer(),
        Text(Money.format(value), style: textStyle),
      ],
    );
  }
}

class _SalaryHistoryList extends ConsumerWidget {
  const _SalaryHistoryList({required this.employeeId});

  final String employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final historyAsync = ref.watch(salaryHistoryProvider);
    return historyAsync.when(
      loading: () => const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text(
        mapErrorToAppException(e).message,
        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.danger),
      ),
      data: (rows) {
        final mine = [
          for (final r in rows)
            if (r.employeeId == employeeId) r,
        ]..sort((a, b) => b.month.compareTo(a.month));
        if (mine.isEmpty) {
          return Text(
            'لا يوجد صرف لهذا الموظف بعد',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.textMuted),
          );
        }
        return Column(
          children: [
            for (final r in mine)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  '${r.month.year}/${r.month.month.toString().padLeft(2, '0')}',
                  style: theme.textTheme.bodyMedium,
                ),
                subtitle: r.date == null
                    ? null
                    : Text(
                        'صُرف في ${r.date!.year}/${r.date!.month.toString().padLeft(2, '0')}/${r.date!.day.toString().padLeft(2, '0')}',
                        style: theme.textTheme.bodySmall,
                      ),
                trailing: Text(
                  Money.format(r.paid),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HintState extends StatelessWidget {
  const _HintState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(FontAwesomeIcons.handshake,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'اختر موظفاً وشهراً لعرض المستحقات',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: Theme.of(context)
          .textTheme
          .bodySmall
          ?.copyWith(color: AppColors.danger),
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