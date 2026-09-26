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
import '../../../data/offline/report_keys.dart';
import '../../../domain/accounts/account.dart';
import '../../../domain/journal/journal.dart';
import '../../../domain/journal/manual_journal_draft.dart';
import '../../providers/accounts_providers.dart';
import '../../providers/journal_providers.dart';
import '../../widgets/freshness_chip.dart';
import '../../widgets/record_table.dart';
import '../../widgets/invoice_input_fields.dart';

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    final range = ref.read(journalRangeProvider);
    _from = range.from;
    _to = range.to;
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _from = picked);
    ref
        .read(journalRangeProvider.notifier)
        .update(from: picked, to: _to.isBefore(picked) ? picked : _to);
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _to = picked);
    ref
        .read(journalRangeProvider.notifier)
        .update(from: _from.isAfter(picked) ? picked : _from, to: picked);
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(journalListProvider);

    return PageScaffold(
      title: 'قيد اليومية',
      subtitle: 'القيود المحاسبية الآلية واليدوية',
      actions: [
        FreshnessChip(cacheKey: journalKey(_from, _to)),
        IconButton(
          tooltip: 'تحديث',
          onPressed: () => ref.invalidate(journalListProvider),
          icon: const FaIcon(FontAwesomeIcons.rotate),
        ),
      ],
      child: Stack(
        children: [
          Column(
            children: [
              _RangeBar(
                from: _from,
                to: _to,
                onFromTap: _pickFrom,
                onToTap: _pickTo,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: AsyncSection<List<JournalEntry>>(
                  value: entriesAsync,
                  onRetry: () => ref.invalidate(journalListProvider),
                  emptyIcon: FontAwesomeIcons.bookOpen,
                  emptyTitle: 'لا توجد قيود في الفترة المحددة',
                  emptyMessage: 'اضغط على + لترحيل قيد يدوي',
                  builder: (context, entries) => RecordTable<JournalEntry>(
                    items: entries,
                    onTap: (e) => _showEntryDetail(context, e),
                    columns: [
                      RecordColumn<JournalEntry>(
                        label: 'الرقم',
                        primary: true,
                        flex: 2,
                        cell: (context, e) => Text(
                          'قيد رقم ${e.entryNo}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      RecordColumn<JournalEntry>(
                        label: 'البيان',
                        flex: 3,
                        cell: (context, e) => Text(
                          e.memo.isEmpty ? 'قيد رقم ${e.entryNo}' : e.memo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      RecordColumn<JournalEntry>(
                        label: 'التاريخ',
                        flex: 2,
                        cell: (context, e) => Text(
                          _fmtDate(e.date),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      RecordColumn<JournalEntry>(
                        label: 'النوع',
                        flex: 2,
                        cell: (context, e) => _SourceBadge(
                          manual: e.sourceType == JournalSourceType.manual,
                        ),
                      ),
                      RecordColumn<JournalEntry>(
                        label: 'الإجمالي',
                        flex: 2,
                        cell: (context, e) => Text(
                          Money.format(e.total),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                    trailing: (context, e) => PopupMenuButton<String>(
                      tooltip: 'خيارات',
                      icon: const FaIcon(
                        FontAwesomeIcons.ellipsisVertical,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                      onSelected: (value) {
                        if (value == 'detail') {
                          _showEntryDetail(context, e);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'detail',
                          child: Row(
                            children: [
                              FaIcon(FontAwesomeIcons.eye, size: 14),
                              SizedBox(width: 8),
                              Text('عرض التفاصيل'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: FloatingActionButton(
              heroTag: 'journal_add',
              tooltip: 'قيد يدوي جديد',
              onPressed: () => _showManualEntry(context),
              child: const FaIcon(FontAwesomeIcons.pen),
            ),
          ),
        ],
      ),
    );
  }

  void _showManualEntry(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ManualEntrySheet(
        onSave: (draft) async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            final result = await ref
                .read(journalListProvider.notifier)
                .createManual(draft);
            if (context.mounted) Navigator.of(context).pop();
            messenger.showSnackBar(
              SnackBar(content: Text('تم إضافة القيد رقم ${result.entryNo}')),
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

  void _showEntryDetail(BuildContext context, JournalEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EntryDetailSheet(entry: entry),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}/${d.month.toString().padLeft(2, '0')}/'
      '${d.day.toString().padLeft(2, '0')}';
}

class _RangeBar extends StatelessWidget {
  const _RangeBar({
    required this.from,
    required this.to,
    required this.onFromTap,
    required this.onToTap,
  });

  final DateTime from;
  final DateTime to;
  final VoidCallback onFromTap;
  final VoidCallback onToTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _DateChip(label: 'من', date: from, onTap: onFromTap),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _DateChip(label: 'إلى', date: to, onTap: onToTap),
        ),
      ],
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const FaIcon(
                FontAwesomeIcons.calendarDays,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$label ${_fmtDate(date)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}/${d.month.toString().padLeft(2, '0')}/'
      '${d.day.toString().padLeft(2, '0')}';
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.manual});

  final bool manual;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (manual ? AppColors.badgeCommissionBg : AppColors.badgePaidBg),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        manual ? 'يدوي' : 'آلي',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: manual ? AppColors.badgeCommissionFg : AppColors.badgePaidFg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EntryDetailSheet extends StatelessWidget {
  const _EntryDetailSheet({required this.entry});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      label: 'القيد رقم ${entry.entryNo}',
                      value: entry.memo.isEmpty ? '—' : entry.memo,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      label: 'التاريخ',
                      value: _fmtDate(entry.date),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'الحساب',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'مدين',
                          textAlign: TextAlign.end,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'دائن',
                          textAlign: TextAlign.end,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  for (final line in entry.lines)
                    _LineRow(
                      code: line.accountCode,
                      name: line.accountName,
                      debit: line.debit,
                      credit: line.credit,
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(flex: 3, child: Text('المجموع')),
                      Expanded(
                        flex: 2,
                        child: Text(
                          Money.format(entry.total),
                          textAlign: TextAlign.end,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          Money.format(entry.total),
                          textAlign: TextAlign.end,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}/${d.month.toString().padLeft(2, '0')}/'
      '${d.day.toString().padLeft(2, '0')}';
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.code,
    required this.name,
    required this.debit,
    required this.credit,
  });

  final String code;
  final String name;
  final int debit;
  final int credit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cell = theme.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              '$code — $name',
              style: cell?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(debit > 0 ? Money.format(debit) : '', style: cell),
          ),
          Expanded(
            flex: 2,
            child: Text(credit > 0 ? Money.format(credit) : '', style: cell),
          ),
        ],
      ),
    );
  }
}

class _ManualEntrySheet extends ConsumerStatefulWidget {
  const _ManualEntrySheet({required this.onSave});

  final Future<void> Function(ManualJournalDraft draft) onSave;

  @override
  ConsumerState<_ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _LineFields {
  String? accountId;
  final debitCtrl = TextEditingController();
  final creditCtrl = TextEditingController();

  int get debit => priceToAgorot(debitCtrl.text) ?? 0;
  int get credit => priceToAgorot(creditCtrl.text) ?? 0;

  bool get isEmpty => accountId == null && debit == 0 && credit == 0;

  void dispose() {
    debitCtrl.dispose();
    creditCtrl.dispose();
  }
}

class _ManualEntrySheetState extends ConsumerState<_ManualEntrySheet> {
  static const _maxLines = 12;

  final _formKey = GlobalKey<FormState>();
  DateTime _date = DateTime.now();
  final _memoCtrl = TextEditingController();
  final List<_LineFields> _lines = [_LineFields(), _LineFields()];
  String? _balanceError;
  bool _submitting = false;

  @override
  void dispose() {
    _memoCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  void _addLine() {
    if (_lines.length >= _maxLines) return;
    setState(() => _lines.add(_LineFields()));
  }

  void _removeLine(int index) {
    if (_lines.length <= 2) return;
    setState(() => _lines.removeAt(index).dispose());
  }

  List<ManualJournalLineDraft> _collect() => [
    for (final l in _lines)
      if (l.accountId != null)
        ManualJournalLineDraft(
          accountId: l.accountId!,
          debit: l.debit,
          credit: l.credit,
        ),
  ];

  String? _validate() {
    for (var i = 0; i < _lines.length; i++) {
      final l = _lines[i];
      if (l.accountId == null) {
        if (l.isEmpty) continue;
        return 'السطر ${i + 1}: اختر الحساب أولاً';
      }
      if (l.debit == 0 && l.credit == 0) {
        return 'السطر ${i + 1}: أدخل مديناً أو دائناً';
      }
      if (l.debit > 0 && l.credit > 0) {
        return 'السطر ${i + 1}: لا يمكن أن يكون مديناً ودائناً معاً';
      }
    }
    final drafts = _collect();
    if (drafts.length < 2) return 'أدخل سطرين على الأقل (مدين ودائن)';
    final draft = ManualJournalDraft(
      date: _date,
      memo: _memoCtrl.text.trim(),
      lines: drafts,
    );
    if (!draft.isBalanced) {
      return 'القيد غير متوازن: مدين ${Money.format(draft.debitTotal)} '
          '≠ دائن ${Money.format(draft.creditTotal)}';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final error = _validate();
    if (error != null) {
      setState(() => _balanceError = error);
      return;
    }
    setState(() {
      _balanceError = null;
      _submitting = true;
    });
    try {
      await widget.onSave(
        ManualJournalDraft(
          date: _date,
          memo: _memoCtrl.text.trim(),
          lines: _collect(),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final chartAsync = ref.watch(chartOfAccountsProvider);
    final accounts = chartAsync.maybeWhen(
      data: (list) => list,
      orElse: () => const <Account>[],
    );

    final debitTotal = _lines.fold<int>(0, (s, l) => s + l.debit);
    final creditTotal = _lines.fold<int>(0, (s, l) => s + l.credit);

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPadding),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const IconChip(
                    icon: FontAwesomeIcons.pen,
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
                          'قيد يدوي جديد',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'أدخل بيانات القيد والسطور',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const FaIcon(
                          FontAwesomeIcons.calendarDays,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'التاريخ: ${_fmtDate(_date)}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _memoCtrl,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'البيان',
                  prefixIcon: FaIcon(FontAwesomeIcons.fileLines),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'السطور',
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _lines.length >= _maxLines ? null : _addLine,
                    icon: const FaIcon(FontAwesomeIcons.plus, size: 14),
                    label: const Text('إضافة سطر'),
                  ),
                ],
              ),
              for (var i = 0; i < _lines.length; i++) ...[
                _ManualLineEditor(
                  index: i,
                  fields: _lines[i],
                  accounts: accounts,
                  accountsLoading: chartAsync.isLoading,
                  accountsError: chartAsync.hasError,
                  canRemove: _lines.length > 2,
                  onChanged: () => setState(() {}),
                  onRemove: () => _removeLine(i),
                ),
                if (i < _lines.length - 1) const SizedBox(height: 8),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(flex: 3, child: Text('المدين')),
                        Expanded(
                          flex: 2,
                          child: Text(
                            Money.format(debitTotal),
                            textAlign: TextAlign.end,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const Expanded(flex: 2, child: Text('')),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Expanded(flex: 3, child: Text('الدائن')),
                        Expanded(
                          flex: 2,
                          child: Text(
                            Money.format(creditTotal),
                            textAlign: TextAlign.end,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const Expanded(flex: 2, child: Text('')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (debitTotal == creditTotal && debitTotal > 0)
                      _StatusPill(balanced: true)
                    else if (debitTotal > 0 || creditTotal > 0)
                      _StatusPill(balanced: false),
                    if (_balanceError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _balanceError!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: AppProgress(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('ترحيل القيد'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}/${d.month.toString().padLeft(2, '0')}/'
      '${d.day.toString().padLeft(2, '0')}';
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.balanced});

  final bool balanced;

  @override
  Widget build(BuildContext context) {
    final color = balanced ? AppColors.success : AppColors.danger;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          balanced ? 'القيد متوازن' : 'القيد غير متوازن',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _ManualLineEditor extends StatelessWidget {
  const _ManualLineEditor({
    required this.index,
    required this.fields,
    required this.accounts,
    required this.accountsLoading,
    required this.accountsError,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final _LineFields fields;
  final List<Account> accounts;
  final bool accountsLoading;
  final bool accountsError;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: fields.accountId,
                decoration: const InputDecoration(
                  labelText: 'الحساب',
                  prefixIcon: FaIcon(FontAwesomeIcons.sitemap),
                ),
                items: [
                  for (final a in accounts)
                    DropdownMenuItem(
                      value: a.id,
                      child: Text('${a.code} — ${a.name}'),
                    ),
                ],
                onChanged: accountsLoading || accountsError || accounts.isEmpty
                    ? null
                    : (v) {
                        fields.accountId = v;
                        onChanged();
                      },
              ),
            ),
            if (canRemove) ...[
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'إزالة السطر ${index + 1}',
                onPressed: onRemove,
                icon: const FaIcon(
                  FontAwesomeIcons.xmark,
                  size: 16,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ],
        ),
        if (accountsError)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'تعذّر تحميل الحسابات — حدّث دليل الحسابات ثم أعد فتح النموذج',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.danger),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: fields.debitCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'مدين',
                  prefixIcon: FaIcon(FontAwesomeIcons.arrowUpFromBracket),
                ),
                onChanged: (_) => onChanged(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: fields.creditCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'دائن',
                  prefixIcon: FaIcon(FontAwesomeIcons.arrowRightToBracket),
                ),
                onChanged: (_) => onChanged(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}