import 'reminder_log_entry.dart';
import 'reminder_settings.dart';

/// Abstract interface for reminder automation.
///
/// Covers reading/updating `tenant_settings`, firing the two send RPCs
/// (single customer + everyone overdue), and reading the `reminder_log` feed.
/// The UI never imports the Supabase client — concrete implementations live
/// in `data/`.
abstract interface class ReminderRepository {
  Future<ReminderSettings> loadSettings();
  Future<void> updateSettings(ReminderSettings settings);

  /// `send_reminders_to_all()` (migration 0020); returns how many customers
  /// were queued (0 when everything already had a same-day reminder).
  Future<int> sendToAll();

  /// `send_reminder_now(customer_id)` (migration 0013); surfaces the RPC's
  /// Arabic rejections (no phone / no dues / missing webhook) as
  /// [AppException]s.
  Future<void> sendReminderNow(String customerId);

  /// Newest-first `reminder_log` rows, limited for the feed view.
  Future<List<ReminderLogEntry>> reminderLog({int limit = 50});
}
