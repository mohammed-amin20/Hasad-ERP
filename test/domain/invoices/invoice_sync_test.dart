import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/domain/invoices/invoice_sync.dart';

void main() {
  group('InvoiceSyncState.fromQueueStatus', () {
    test('pending and staged both mean work still to replay', () {
      expect(
        InvoiceSyncState.fromQueueStatus('pending'),
        InvoiceSyncState.pending,
      );
      expect(
        InvoiceSyncState.fromQueueStatus('staged'),
        InvoiceSyncState.pending,
      );
    });

    test('failed is failed', () {
      expect(
        InvoiceSyncState.fromQueueStatus('failed'),
        InvoiceSyncState.failed,
      );
    });

    test('synced is synced', () {
      expect(
        InvoiceSyncState.fromQueueStatus('synced'),
        InvoiceSyncState.synced,
      );
    });

    test('syncing maps even though no flusher writes that status today', () {
      expect(
        InvoiceSyncState.fromQueueStatus('syncing'),
        InvoiceSyncState.syncing,
      );
    });

    // The load-bearing default. Absence of a leg is exactly what "already on
    // the server" looks like, and an unknown FUTURE status must never degrade
    // to the alarming state — that would badge every row in the app after an
    // upgrade that adds a status value.
    test('null, empty and unknown statuses degrade to synced, never pending', () {
      expect(InvoiceSyncState.fromQueueStatus(null), InvoiceSyncState.synced);
      expect(InvoiceSyncState.fromQueueStatus(''), InvoiceSyncState.synced);
      expect(
        InvoiceSyncState.fromQueueStatus('some_future_status'),
        InvoiceSyncState.synced,
      );
    });
  });

  group('labels', () {
    test('every state has a non-empty, distinct label', () {
      final labels = {for (final s in InvoiceSyncState.values) s.label};
      expect(labels.length, InvoiceSyncState.values.length);
      expect(labels.every((l) => l.trim().isNotEmpty), isTrue);
    });

    test('pending, syncing and failed are all spelled out', () {
      // The indicator must never rely on colour alone, so every state the UI
      // can render needs its own wording rather than a shared generic label.
      expect(InvoiceSyncState.pending.label, isNot(InvoiceSyncState.failed.label));
      expect(InvoiceSyncState.syncing.label, isNot(InvoiceSyncState.pending.label));
      expect(InvoiceSyncState.synced.label, isNot(InvoiceSyncState.pending.label));
    });
  });
}
