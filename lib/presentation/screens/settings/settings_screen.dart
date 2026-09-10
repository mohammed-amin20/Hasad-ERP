import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_progress.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../domain/reminders/reminder_log_entry.dart';
import '../../../domain/reminders/reminder_settings.dart';
import '../../providers/reminders_providers.dart';

/// Reminder automation + company settings (admin-only tab).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<void> _saveSettings(ReminderSettings settings) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(reminderSettingsControllerProvider.notifier)
          .save(settings);
      messenger.showSnackBar(const SnackBar(content: Text('تم حفظ الإعدادات')));
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text(mapErrorToAppException(error).message),
        ),
      );
    }
  }

  Future<void> _sendToAll() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final sent = await ref.read(reminderLogProvider.notifier).sendToAll();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            sent > 0
                ? 'تم إرسال تذكير لـ $sent عميل'
                : 'لا يوجد عملاء مستحقون للتذكير اليوم',
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
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(reminderSettingsControllerProvider);

    return PageScaffold(
      title: 'الإعدادات',
      subtitle: 'إعدادات المنشأة والتذكيرات والنسخ الاحتياطي',
      child: settingsAsync.when(
        loading: () => const Center(child: AppProgress()),
        error: (e, _) => _ErrorState(message: e.toString()),
        data: (settings) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ReminderSettingsForm(
                      key: ValueKey(settings),
                      initial: settings,
                      onSave: _saveSettings,
                    ),
                    const SizedBox(height: 24),
                    _SendAllCard(onSend: _sendToAll),
                    const SizedBox(height: 24),
                    const _ReminderLogCard(),
                    const SizedBox(height: 24),
                    const _BackupCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Editable webhook + template + policy. Re-initialized (new key) whenever the
/// parent settings value changes so the form always shows the saved row.
class _ReminderSettingsForm extends StatefulWidget {
  const _ReminderSettingsForm({
    super.key,
    required this.initial,
    required this.onSave,
  });

  final ReminderSettings initial;
  final Future<void> Function(ReminderSettings settings) onSave;

  @override
  State<_ReminderSettingsForm> createState() => _ReminderSettingsFormState();
}

class _ReminderSettingsFormState extends State<_ReminderSettingsForm> {
  static const _thresholdItems = <(int, String)>[
    (0, 'فوراً بعد الاستحقاق'),
    (1, 'بعد يوم'),
    (2, 'بعد يومين'),
    (3, 'بعد 3 أيام'),
    (5, 'بعد 5 أيام'),
    (7, 'بعد أسبوع'),
    (14, 'بعد 14 يوماً'),
    (30, 'بعد 30 يوماً'),
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _webhookCtrl;
  late final TextEditingController _messageCtrl;
  late int _threshold;
  late bool _enabled;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _webhookCtrl = TextEditingController(text: widget.initial.webhookUrl ?? '');
    _messageCtrl = TextEditingController(text: widget.initial.message);
    _threshold = widget.initial.daysThreshold;
    _enabled = widget.initial.enabled;
  }

  @override
  void dispose() {
    _webhookCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  void _insertPlaceholder(String placeholder) {
    final ctrl = _messageCtrl;
    final selection = ctrl.selection;
    final start = selection.isValid ? selection.start : ctrl.text.length;
    ctrl.text = ctrl.text.replaceRange(
      start,
      selection.isValid ? selection.end : start,
      placeholder,
    );
    ctrl.selection = TextSelection.collapsed(
      offset: start + placeholder.length,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final webhook = _webhookCtrl.text;
      await widget.onSave(
        ReminderSettings(
          tenantId: widget.initial.tenantId,
          webhookUrl: webhook.trim().isEmpty ? null : webhook.trim(),
          message: _messageCtrl.text.trim().isEmpty
              ? ReminderSettings.defaultMessageTemplate
              : _messageCtrl.text.trim(),
          daysThreshold: _threshold,
          enabled: _enabled,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SectionCard(
      icon: FontAwesomeIcons.bell,
      color: AppColors.primary,
      title: 'إعدادات التذكيرات',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _webhookCtrl,
              keyboardType: TextInputType.url,
              autofillHints: const [AutofillHints.url],
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: const InputDecoration(
                labelText: 'رابط Webhook (n8n)',
                hintText: 'https://...',
                prefixIcon: FaIcon(FontAwesomeIcons.link, size: 16),
                helperText: 'اتركه فارغاً لتعطيل إرسال التذكيرات',
              ),
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.isEmpty) return null;
                if (!v.startsWith('https://') && !v.startsWith('http://')) {
                  return 'أدخل رابطاً يبدأ بـ http:// أو https://';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _messageCtrl,
              maxLines: 4,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                labelText: 'قالب الرسالة',
                prefixIcon: FaIcon(FontAwesomeIcons.message, size: 16),
                alignLabelWithHint: true,
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'أدخل نص الرسالة'
                  : null,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final placeholder in ReminderSettings.placeholders)
                  ActionChip(
                    label: Text(
                      placeholder,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    backgroundColor: AppColors.primary.withValues(alpha: 0.06),
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.25),
                    ),
                    onPressed: () => _insertPlaceholder(placeholder),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<int>(
              initialValue: _threshold,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'إرسال تذكير بعد',
                prefixIcon: FaIcon(FontAwesomeIcons.clock, size: 16),
              ),
              items: [
                if (!_thresholdItems.any((e) => e.$1 == _threshold))
                  DropdownMenuItem(
                    value: _threshold,
                    child: Text('بعد $_threshold يوماً'),
                  ),
                for (final (value, label) in _thresholdItems)
                  DropdownMenuItem(value: value, child: Text(label)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _threshold = value);
              },
            ),
            Material(
              type: MaterialType.transparency,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('تفعيل التذكيرات اليومية التلقائية'),
                subtitle: const Text(
                  'يعمل على الجدولة الصباحية الأوتوماتيكية فقط',
                ),
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: AppProgress(strokeWidth: 2),
                      )
                    : const FaIcon(FontAwesomeIcons.floppyDisk, size: 16),
                label: const Text('حفظ الإعدادات'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SendAllCard extends ConsumerWidget {
  const _SendAllCard({required this.onSend});

  final VoidCallback onSend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return _SectionCard(
      icon: FontAwesomeIcons.paperPlane,
      color: AppColors.secondary,
      title: 'إرسال التذكيرات',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'إرسال تذكير لكل العملاء المتأخرين عن السداد دفعة واحدة (لا يُرسل لأي عميل أُرسل له تذكير اليوم).',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: ElevatedButton.icon(
              onPressed: onSend,
              icon: const FaIcon(FontAwesomeIcons.paperPlane, size: 16),
              label: const Text('إرسال للجميع الآن'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderLogCard extends ConsumerWidget {
  const _ReminderLogCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final logAsync = ref.watch(reminderLogProvider);

    return Semantics(
      liveRegion: true,
      child: _SectionCard(
      icon: FontAwesomeIcons.inbox,
      color: AppColors.info,
      title: 'سجل الرسائل',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 96,
                child: Text(
                  'التاريخ',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'العميل',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  'المبلغ',
                  textAlign: TextAlign.end,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 56,
                child: Text(
                  'الحالة',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          logAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: AppProgress()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                e.toString(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.danger,
                ),
              ),
            ),
            data: (entries) {
              if (entries.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'لا توجد رسائل بعد',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                );
              }
              return Column(
                children: [for (final entry in entries) _LogRow(entry: entry)],
              );
            },
          ),
        ],
      ),
    ),
  );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry});

  final ReminderLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              _fmtDateTime(entry.createdAt.toLocal()),
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Text(
              entry.customerName ?? 'عميل محذوف',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              entry.amountText ?? '—',
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 56,
            child: entry.failed
                ? StatusBadge(label: 'فشل', palette: BadgePalette.unpaid)
                : StatusBadge(label: 'أُرسل', palette: BadgePalette.paid),
          ),
        ],
      ),
    );
  }
}

class _BackupCard extends StatelessWidget {
  const _BackupCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SectionCard(
      icon: FontAwesomeIcons.database,
      color: AppColors.textMuted,
      title: 'النسخ الاحتياطي',
      child: Row(
        children: [
          Expanded(
            child: Text(
              'النسخ الاحتياطي والاستعادة الكاملان غير متاحين بعد — يتم توثيقهما في مرحلة قادمة.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.child,
  });

  final FaIconData icon;
  final Color color;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              FaIcon(icon, size: 16, color: color),
              const SizedBox(width: 10),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            Text('حدث خطأ', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _fmtDateTime(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}/${d.month.toString().padLeft(2, '0')}/'
    '${d.day.toString().padLeft(2, '0')} '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
