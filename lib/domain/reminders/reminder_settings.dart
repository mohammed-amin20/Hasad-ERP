/// Per-tenant reminder automation settings (`tenant_settings`, migration 0013).
class ReminderSettings {
  const ReminderSettings({
    this.tenantId,
    this.webhookUrl,
    this.message = defaultMessageTemplate,
    this.daysThreshold = 3,
    this.enabled = true,
  });

  factory ReminderSettings.empty() => const ReminderSettings();

  factory ReminderSettings.fromJson(Map<String, dynamic> json) =>
      ReminderSettings(
        tenantId: json['tenant_id'] as String?,
        webhookUrl: json['reminder_webhook_url'] as String?,
        message: (json['reminder_message'] as String?) ??
            defaultMessageTemplate,
        daysThreshold: (json['reminder_days_threshold'] as num?)?.toInt() ?? 3,
        enabled: json['reminder_enabled'] as bool? ?? true,
      );

  /// Standard template shipped by migration 0013 (single source for the UI
  /// template field, and the restore default used by `reminders.ps1`).
  static const defaultMessageTemplate =
      '{customer_name}، يرجى سداد مبلغ {amount} شيكل لمؤسسة {company_name}. للاستفسار: {phone}';

  /// Tokens the template supports; the settings screen surfaces these to the
  /// user instead of a raw `{...}` guessing game.
  static const placeholders = [
    '{customer_name}',
    '{amount}',
    '{company_name}',
    '{phone}',
  ];

  final String? tenantId;
  final String? webhookUrl;
  final String message;
  final int daysThreshold;
  final bool enabled;

  /// Payload for `PATCH tenant_settings`. A cleared webhook is sent as JSON
  /// null so PostgREST sets the column back to SQL NULL.
  Map<String, dynamic> toUpdateJson() => {
        'reminder_webhook_url': webhookUrl,
        'reminder_message': message,
        'reminder_days_threshold': daysThreshold,
        'reminder_enabled': enabled,
      };
}