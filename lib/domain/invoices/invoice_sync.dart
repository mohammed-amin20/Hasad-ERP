/// Sync state of an invoice row, derived from its `sync_queue` leg.
///
/// This is deliberately **not** a field on `Invoice`. It is live view state
/// read from the queue, never part of the invoice's persisted identity, and
/// `Invoice.fromJson` parses the JSON cache — where no such key exists — so a
/// field there would have to invent a value for every cached payload.
enum InvoiceSyncState {
  pending,
  syncing,
  synced,
  failed;

  /// Maps a `sync_queue.status` column onto a display state.
  ///
  /// A null/unknown status means [synced]: absence of a queue leg is exactly
  /// what "already on the server" looks like, so the fallback must never be
  /// the alarming one.
  ///
  /// 'staged' is treated as [pending] because the flusher treats it as
  /// un-replayed work.
  static InvoiceSyncState fromQueueStatus(String? status) => switch (status) {
    'pending' || 'staged' => InvoiceSyncState.pending,
    'syncing' => InvoiceSyncState.syncing,
    'failed' => InvoiceSyncState.failed,
    _ => InvoiceSyncState.synced,
  };

  String get label => switch (this) {
    InvoiceSyncState.pending => 'بانتظار المزامنة',
    InvoiceSyncState.syncing => 'جارٍ المزامنة',
    InvoiceSyncState.failed => 'فشلت المزامنة',
    InvoiceSyncState.synced => 'مُزامنة',
  };
}
