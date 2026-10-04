/// Payload for `adjust_inventory` — a physical inventory count result.
class StockAdjustDraft {
  const StockAdjustDraft({
    required this.productId,
    required this.countedQty,
    this.reason,
    this.date,
  });

  final String productId;
  final double countedQty;
  final String? reason;
  final DateTime? date;

  /// Builds the `adjust_inventory` RPC payload.
  ///
  /// [requestId] is the offline queue's stable idempotency key: a queued count
  /// leg stores these exact params, so every retry replays the SAME
  /// `p_request_id` and the server (0025) recognises the replay instead of
  /// applying the delta twice.
  Map<String, dynamic> toJson({String? requestId}) => {
    'p_product_id': productId,
    'p_counted_qty': countedQty,
    if (reason != null && reason!.trim().isNotEmpty) 'p_reason': reason,
    if (date != null)
      'p_date': date != null
          ? '${date!.year.toString().padLeft(4, '0')}-'
                '${date!.month.toString().padLeft(2, '0')}-'
                '${date!.day.toString().padLeft(2, '0')}'
          : null,
    'p_request_id': ?requestId,
  };}

/// Result envelope returned by the `adjust_inventory` RPC.
class StockAdjustResult {
  const StockAdjustResult({
    required this.productId,
    this.productName,
    required this.oldQty,
    required this.newQty,
    required this.delta,
    required this.changed,
  });

  final String productId;
  final String? productName;
  final double oldQty;
  final double newQty;
  final double delta;
  final bool changed;

  factory StockAdjustResult.fromJson(Map<String, dynamic> json) =>
      StockAdjustResult(
        productId: json['product_id'] as String,
        productName: json['name'] as String?,
        oldQty: (json['old_qty'] as num?)?.toDouble() ?? 0,
        newQty: (json['new_qty'] as num?)?.toDouble() ?? 0,
        delta: (json['delta'] as num?)?.toDouble() ?? 0,
        changed: json['changed'] as bool? ?? false,
      );
}
