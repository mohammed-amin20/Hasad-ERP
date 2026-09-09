import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/domain/reminders/reminder_log_entry.dart';
import 'package:hasad_erp/domain/reminders/reminder_settings.dart';

void main() {
  const tenantId = 'ef95064e-b867-4b7f-bd98-36748066cc8c';
  const customerId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

  group('ReminderSettings', () {
    test('fromJson parses a full settings row', () {
      final settings = ReminderSettings.fromJson({
        'tenant_id': tenantId,
        'reminder_webhook_url': 'https://n8n.example.invalid/webhook',
        'reminder_message': 'مساء الخير {customer_name}، يرجى سداد {amount}',
        'reminder_days_threshold': 2,
        'reminder_enabled': false,
      });

      expect(settings.tenantId, tenantId);
      expect(settings.webhookUrl, 'https://n8n.example.invalid/webhook');
      expect(settings.message, 'مساء الخير {customer_name}، يرجى سداد {amount}');
      expect(settings.daysThreshold, 2);
      expect(settings.enabled, isFalse);
    });

    test('fromJson tolerates a null webhook and fills defaults', () {
      final settings = ReminderSettings.fromJson({
        'tenant_id': tenantId,
        'reminder_webhook_url': null,
        'reminder_message': null,
      });

      expect(settings.webhookUrl, isNull);
      expect(settings.message, ReminderSettings.defaultMessageTemplate);
      expect(settings.daysThreshold, 3);
      expect(settings.enabled, isTrue);
    });

    test('empty uses the shipped defaults', () {
      final settings = ReminderSettings.empty();

      expect(settings.tenantId, isNull);
      expect(settings.webhookUrl, isNull);
      expect(settings.message, ReminderSettings.defaultMessageTemplate);
      expect(settings.daysThreshold, 3);
      expect(settings.enabled, isTrue);
    });

    test('toUpdateJson carries a cleared webhook as JSON null', () {
      final settings = ReminderSettings(
        tenantId: tenantId,
        webhookUrl: null,
        message: 'رسالة',
        daysThreshold: 0,
        enabled: true,
      );

      final json = settings.toUpdateJson();
      expect(json.containsKey('reminder_webhook_url'), isTrue);
      expect(json['reminder_webhook_url'], isNull);
      expect(json['reminder_message'], 'رسالة');
      expect(json['reminder_days_threshold'], 0);
      expect(json['reminder_enabled'], isTrue);
    });

    test('placeholders all exist in the default template', () {
      for (final placeholder in ReminderSettings.placeholders) {
        expect(
          ReminderSettings.defaultMessageTemplate.contains(placeholder),
          isTrue,
          reason: 'template must reference $placeholder',
        );
      }
    });
  });

  group('ReminderLogEntry', () {
    test('fromJson parses a row with embedded customer name', () {
      final entry = ReminderLogEntry.fromJson({
        'id': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        'customer_id': customerId,
        'customers': {'name': 'عميل تذكير'},
        'amount': 20000,
        'phone': '0599111222',
        'message': 'عميل تذكير يرجى سداد 200.00 شيكل',
        'status': 'sent',
        'created_at': '2026-09-09T09:00:00+00:00',
      });

      expect(entry.customerId, customerId);
      expect(entry.customerName, 'عميل تذكير');
      expect(entry.amount, 20000);
      expect(entry.amountText, '200');
      expect(entry.phone, '0599111222');
      expect(entry.status, 'sent');
      expect(entry.createdAt.isUtc, isTrue);
      expect(entry.failed, isFalse);
    });

    test('fromJson tolerates a missing embed and null amount', () {
      final entry = ReminderLogEntry.fromJson({
        'id': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        'customer_id': null,
        'amount': null,
        'message': 'رسالة',
        'status': 'failed',
        'created_at': '2026-09-09T09:05:00+00:00',
      });

      expect(entry.customerId, isNull);
      expect(entry.customerName, isNull);
      expect(entry.amount, isNull);
      expect(entry.amountText, isNull);
      expect(entry.failed, isTrue);
    });
  });
}