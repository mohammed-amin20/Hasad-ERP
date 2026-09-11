import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/reminders/supabase_reminder_repository.dart';
import '../../data/supabase_client.dart';
import '../../domain/reminders/reminder_log_entry.dart';
import '../../domain/reminders/reminder_repository.dart';
import '../../domain/reminders/reminder_settings.dart';

part 'reminders_providers.g.dart';

/// Reminder repository wired to Supabase.
@riverpod
ReminderRepository reminderRepository(Ref ref) =>
    SupabaseReminderRepository(ref.watch(supabaseClientProvider));

/// The current tenant's reminder settings (webhook, template, threshold).
@riverpod
class ReminderSettingsController extends _$ReminderSettingsController {
  @override
  Future<ReminderSettings> build() =>
      ref.watch(reminderRepositoryProvider).loadSettings();

  /// Persist edits via the repository, then reload so the UI reflects what
  /// the database accepted.
  Future<void> save(ReminderSettings settings) async {
    await ref.read(reminderRepositoryProvider).updateSettings(settings);
    ref.invalidateSelf();
  }
}

/// Most recent reminder sends, newest first.
@riverpod
class ReminderLog extends _$ReminderLog {
  @override
  Future<List<ReminderLogEntry>> build() =>
      ref.watch(reminderRepositoryProvider).reminderLog();

  /// Fire "remind everyone overdue" (migration 0020), then refresh the feed
  /// so the new log rows appear. Returns how many customers were queued.
  Future<int> sendToAll() async {
    final sent = await ref.read(reminderRepositoryProvider).sendToAll();
    ref.invalidateSelf();
    return sent;
  }
}
