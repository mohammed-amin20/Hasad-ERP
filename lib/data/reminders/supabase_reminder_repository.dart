import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/app_exception.dart';
import '../../domain/reminders/reminder_log_entry.dart';
import '../../domain/reminders/reminder_repository.dart';
import '../../domain/reminders/reminder_settings.dart';

/// [ReminderRepository] backed by `tenant_settings` + `reminder_log`
/// (migration 0013) and the `send_reminder_now` / `send_reminders_to_all`
/// RPCs (0013 + 0020). RLS scopes both tables to the caller's tenant.
class SupabaseReminderRepository implements ReminderRepository {
  const SupabaseReminderRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<ReminderSettings> loadSettings() async {
    try {
      final row = await _client
          .from('tenant_settings')
          .select('*')
          .maybeSingle();
      // Reading is RLS-scoped, so a null row means this tenant's row is
      // missing (normally impossible — migration 0013 seeds it via trigger).
      if (row == null) return ReminderSettings.empty();
      return ReminderSettings.fromJson(row);
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  @override
  Future<void> updateSettings(ReminderSettings settings) async {
    final tenantId = settings.tenantId;
    if (tenantId == null) {
      throw const ValidationException('بيانات الإعدادات غير متاحة');
    }
    try {
      await _client
          .from('tenant_settings')
          .update(settings.toUpdateJson())
          .eq('tenant_id', tenantId);
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  @override
  Future<int> sendToAll() async {
    try {
      final result =
          await _client.rpc('send_reminders_to_all') as Map<String, dynamic>;
      return (result['sent'] as num?)?.toInt() ?? 0;
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  @override
  Future<void> sendReminderNow(String customerId) async {
    try {
      await _client.rpc(
        'send_reminder_now',
        params: {'p_customer_id': customerId},
      );
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  @override
  Future<List<ReminderLogEntry>> reminderLog({int limit = 50}) async {
    try {
      final rows = await _client
          .from('reminder_log')
          .select(
            'id, customer_id, amount, phone, message, status, '
            'created_at, customers(name)',
          )
          .order('created_at', ascending: false)
          .limit(limit);
      return rows.map(ReminderLogEntry.fromJson).toList();
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }
}