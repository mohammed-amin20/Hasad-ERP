import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/printing/statement_pdf.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/route_header.dart';
import '../../../domain/statements/statement.dart';
import '../../providers/statements_providers.dart';

/// Account statement for one party with a MANDATORY from/to date filter.
class StatementScreen extends ConsumerStatefulWidget {
  const StatementScreen({
    super.key,
    required this.partyType,
    required this.partyId,
    required this.partyName,
  });

  final String partyType;
  final String partyId;
  final String partyName;

  @override
  ConsumerState<StatementScreen> createState() => _StatementScreenState();
}

class _StatementScreenState extends ConsumerState<StatementScreen> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();
  bool _submitted = false;
  bool _printing = false;
  StatementRequest? _request;

  @override
  void initState() {
    super.initState();
    _request = StatementRequest(
      partyType: widget.partyType,
      partyId: widget.partyId,
      from: _from,
      to: _to,
    );
  }

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

  void _apply() {
    if (_from.isAfter(_to)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('تاريخ البداية بعد تاريخ النهاية'),
        ),
      );
      return;
    }
    setState(() {
      _submitted = true;
      _request = StatementRequest(
        partyType: widget.partyType,
        partyId: widget.partyId,
        from: _from,
        to: _to,
      );
    });
  }

  Future<void> _printPdf(PartyStatement statement) async {
    setState(() => _printing = true);
    try {
      final bytes = await StatementPdf.build(
        statement: statement,
        partyName: widget.partyName,
        partyType: widget.partyType,
      );
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('تعذر إنشاء ملف PDF: ${e.toString()}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statementAsync = _submitted
        ? ref.watch(partyStatementProvider(_request!))
        : null;
    final statement = statementAsync?.value;

return Container(
      color: AppColors.background,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: RouteHeader(
                title: 'كشف حساب — ${widget.partyName}',
                subtitle: 'عرض حركة الحساب وطباعتها',
                onClose: () => Navigator.of(context).pop(),
                actions: [
                  if (statement != null)
                    IconButton(
                      onPressed: _printing ? null : () => _printPdf(statement),
                      tooltip: 'طباعة / PDF',
                      icon: _printing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const FaIcon(FontAwesomeIcons.print, size: 18),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickFrom,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'من تاريخ',
                              prefixIcon:
                                  FaIcon(FontAwesomeIcons.calendarDay),
                            ),
                            child: Text(formatDate(_from)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: _pickTo,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'إلى تاريخ',
                              prefixIcon:
                                  FaIcon(FontAwesomeIcons.calendarDay),
                            ),
                            child: Text(formatDate(_to)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _apply,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('عرض الكشف'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: statementAsync?.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      e.toString(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.danger),
                    ),
                  ),
                ),
                data: (st) => _StatementBody(statement: st),
              ) ??
                  const _PromptState(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatementBody extends StatelessWidget {
  const _StatementBody({required this.statement});

  final PartyStatement statement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Row(
            children: [
              Expanded(
                child: _SummaryCard(
                    label: 'الرصيد الافتتاحي', value: statement.opening),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  label: 'الرصيد الختامي',
                  value: statement.closing,
                  emphasized: true,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text('البيان',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary)),
                  ),
                  Expanded(
                    child: Text('مدين',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary)),
                  ),
                  Expanded(
                    child: Text('دائن',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary)),
                  ),
                  Expanded(
                    child: Text('الرصيد',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _LineRow(
                date: null,
                label: 'رصيد سابق',
                debit: 0,
                credit: 0,
                balance: statement.opening,
                headerStyle: true,
              ),
              if (statement.lines.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'لا توجد حركات في هذه الفترة',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              for (final entry in _runs()) ...[
                _LineRow(
                  date: entry.line.date,
                  label: _lineLabel(entry.line),
                  debit: entry.line.debit,
                  credit: entry.line.credit,
                  balance: entry.balance,
                ),
                const Divider(height: 20),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Iterable<_Run> _runs() {
    var running = statement.opening;
    return [
      for (final line in statement.lines)
        _Run(line: line, balance: running += line.balance),
    ];
  }

  String _lineLabel(StatementLine line) {
    final ref = line.ref;
    final refPart = ref != null ? ' ($ref)' : '';
    switch (line.kind) {
      case StatementLineKind.invoice:
        return 'فاتورة$refPart';
      case StatementLineKind.payment:
        return 'دفعة$refPart';
      case StatementLineKind.commission:
        return 'عمولة$refPart';
    }
  }
}

class _Run {
  const _Run({required this.line, required this.balance});

  final StatementLine line;
  final int balance;
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.date,
    required this.label,
    required this.debit,
    required this.credit,
    required this.balance,
    this.headerStyle = false,
  });

  final DateTime? date;
  final String label;
  final int debit;
  final int credit;
  final int balance;
  final bool headerStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = headerStyle
        ? theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)
        : theme.textTheme.bodyMedium;
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: style),
              if (date != null)
                Text(
                  formatDate(date!),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
        Expanded(
          child: Text(
            debit > 0 ? Money.format(debit) : '',
            textAlign: TextAlign.end,
            style: debit > 0
                ? style?.copyWith(color: AppColors.danger)
                : style,
          ),
        ),
        Expanded(
          child: Text(
            credit > 0 ? Money.format(credit) : '',
            textAlign: TextAlign.end,
            style: credit > 0
                ? style?.copyWith(color: AppColors.primary)
                : style,
          ),
        ),
        Expanded(
          child: Text(
            Money.format(balance),
            textAlign: TextAlign.end,
            style: style?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final int value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = emphasized ? AppColors.primary : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  theme.textTheme.bodySmall?.copyWith(color: color)),
          const SizedBox(height: 4),
          Text(
            Money.format(value),
            style: theme.textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptState extends StatelessWidget {
  const _PromptState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FaIcon(FontAwesomeIcons.receipt,
                size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text('اختر الفترة ثم اضغط "عرض الكشف"',
                style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

String formatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}/${d.month.toString().padLeft(2, '0')}/'
    '${d.day.toString().padLeft(2, '0')}';

