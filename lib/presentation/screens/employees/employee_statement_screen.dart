import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/printing/employee_slip_pdf.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../domain/salaries/salary_repository.dart';
import '../../providers/salaries_providers.dart';

/// Per-employee monthly salary statement with a printable PDF payslip.
class EmployeeStatementScreen extends ConsumerStatefulWidget {
  const EmployeeStatementScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
  });

  final String employeeId;
  final String employeeName;

  @override
  ConsumerState<EmployeeStatementScreen> createState() =>
      _EmployeeStatementScreenState();
}

class _EmployeeStatementScreenState
    extends ConsumerState<EmployeeStatementScreen> {
  DateTime _from = DateTime(DateTime.now().year, 1, 1);
  DateTime _to = firstOfMonth(DateTime.now());

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _from = picked);
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _to = picked);
  }

  bool _validRange() => !_from.isAfter(_to);

  @override
  Widget build(BuildContext context) {
    final request =
        EmployeeStatementRequest(employeeId: widget.employeeId, from: _from, to: _to);
    final statementAsync = ref.watch(employeeStatementProvider(request));
    final valid = _validRange();

    return PageScaffold(
      title: 'حركة رواتب الموظف',
      subtitle: widget.employeeName,
      actions: [
        if (valid)
          IconButton(
            tooltip: 'طباعة/PDF',
            onPressed: () async {
              final st = statementAsync.value;
              if (st == null) return;
              final messenger = ScaffoldMessenger.of(context);
              try {
                await Printing.layoutPdf(
                  onLayout: (_) =>
                      EmployeeSlipPdf.build(statement: st, employeeName: widget.employeeName),
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
            icon: const FaIcon(FontAwesomeIcons.print),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _pickFrom,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'من شهر',
                      prefixIcon: FaIcon(FontAwesomeIcons.calendarDay),
                    ),
                    child: Text(_monthLabel(_from)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _pickTo,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'إلى شهر',
                      prefixIcon: FaIcon(FontAwesomeIcons.calendarDay),
                    ),
                    child: Text(_monthLabel(_to)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!valid)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'نطاق التاريخ غير صحيح — يجب ألا تكون البداية بعد النهاية',
                style: TextStyle(color: AppColors.danger, fontSize: 12),
              ),
            ),
          Expanded(
            child: statementAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorState(message: e.toString()),
              data: (statement) => _buildStatement(context, statement),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatement(BuildContext context, EmployeeStatement statement) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryBox(
                    label: 'متبقٍ سابق',
                    value: statement.opening,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _SummaryBox(
                    label: 'إجمالي المتبقي الختامي',
                    value: statement.closing,
                    color: AppColors.primary,
                    emphasized: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (statement.lines.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'لا توجد حركات رواتب في هذه الفترة',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textMuted),
              ),
            ),
          )
        else
          Card(
            margin: EdgeInsets.zero,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(4),
              child: _StatementTable(lines: statement.lines),
            ),
          ),
      ],
    );
  }
}

class _StatementTable extends StatelessWidget {
  const _StatementTable({required this.lines});

  final List<EmployeeMonthLine> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: AppColors.textMuted,
    );
    final cellStyle = theme.textTheme.bodySmall;
    const minWidth = 72.0;

    return Table(
      defaultColumnWidth: const FixedColumnWidth(minWidth),
      border: TableBorder(
        horizontalInside: BorderSide(
          width: 0.4,
          color: AppColors.border,
        ),
      ),
      children: [
        TableRow(
          children: [
            for (final h in const [
              'الشهر',
              'الأساس',
              'متأخرات',
              'إضافات',
              'خصومات',
              'الصافي',
              'المدفوع',
              'المتبقي',
            ])
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(h, textAlign: TextAlign.end, style: headerStyle),
              ),
          ],
        ),
        for (final line in lines)
          TableRow(
            children: [
              _cell(_monthLabel(line.month), cellStyle, bold: true),
              _cell(Money.format(line.baseSalary), cellStyle),
              _cell(Money.format(line.arrears), cellStyle),
              _cell(
                Money.format(line.entitlements),
                cellStyle,
                color: AppColors.success,
              ),
              _cell(
                Money.format(line.deductions),
                cellStyle,
                color: AppColors.danger,
              ),
              _cell(Money.format(line.netDue), cellStyle, bold: true),
              _cell(Money.format(line.paid), cellStyle),
              _cell(
                Money.format(line.remaining),
                cellStyle,
                bold: true,
                color: line.remaining > 0 ? AppColors.danger : null,
              ),
            ],
          ),
      ],
    );
  }

  Widget _cell(
    String text,
    TextStyle? style, {
    bool bold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        textAlign: TextAlign.end,
        style: style?.copyWith(
          fontWeight: bold ? FontWeight.w700 : null,
          color: color,
        ),
      ),
    );
  }
}

class _SummaryBox extends StatelessWidget {
  const _SummaryBox({
    required this.label,
    required this.value,
    this.color = AppColors.textMuted,
    this.emphasized = false,
  });

  final String label;
  final int value;
  final Color color;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 4),
        Text(
          Money.format(value),
          style: (emphasized ? theme.textTheme.titleLarge : theme.textTheme.titleMedium)
              ?.copyWith(fontWeight: FontWeight.w700, color: color),
        ),
      ],
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

String _monthLabel(DateTime month) =>
    '${month.year}/${month.month.toString().padLeft(2, '0')}';