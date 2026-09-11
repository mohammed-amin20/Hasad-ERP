/// One movement line in a party statement (`get_party_statement`).
enum StatementLineKind {
  invoice,
  payment,
  commission;

  static StatementLineKind from(String value) => switch (value) {
    'payment' => StatementLineKind.payment,
    'commission' => StatementLineKind.commission,
    _ => StatementLineKind.invoice,
  };

  String get label => switch (this) {
    StatementLineKind.invoice => 'فاتورة',
    StatementLineKind.payment => 'دفعة',
    StatementLineKind.commission => 'عمولة',
  };
}

class StatementLine {
  const StatementLine({
    required this.date,
    required this.kind,
    this.ref,
    this.note,
    required this.debit,
    required this.credit,
  });

  final DateTime date;
  final StatementLineKind kind;
  final String? ref;
  final String? note;
  final int debit;
  final int credit;

  int get balance => debit - credit;

  factory StatementLine.fromJson(Map<String, dynamic> json) => StatementLine(
    date: DateTime.parse(json['date'] as String),
    kind: StatementLineKind.from(json['kind'] as String? ?? 'invoice'),
    ref: json['ref'] as String?,
    note: json['note'] as String?,
    debit: (json['debit'] as num?)?.toInt() ?? 0,
    credit: (json['credit'] as num?)?.toInt() ?? 0,
  );
}

/// Request a `get_party_statement` RPC call.
class StatementRequest {
  const StatementRequest({
    required this.partyType,
    required this.partyId,
    required this.from,
    required this.to,
  });

  final String partyType;
  final String partyId;
  final DateTime from;
  final DateTime to;

  Map<String, dynamic> toJson() => {
    'p_party_type': partyType,
    'p_party_id': partyId,
    'p_from':
        '${from.year.toString().padLeft(4, '0')}-'
        '${from.month.toString().padLeft(2, '0')}-'
        '${from.day.toString().padLeft(2, '0')}',
    'p_to':
        '${to.year.toString().padLeft(4, '0')}-'
        '${to.month.toString().padLeft(2, '0')}-'
        '${to.day.toString().padLeft(2, '0')}',
  };
}

/// Loads financial statements via the `get_party_statement` RPC.
abstract class StatementRepository {
  Future<PartyStatement> statement(StatementRequest request);
}

/// A full account statement for one customer or supplier.
class PartyStatement {
  const PartyStatement({
    required this.partyType,
    required this.partyId,
    required this.from,
    required this.to,
    required this.opening,
    required this.closing,
    required this.lines,
  });

  final String partyType;
  final String partyId;
  final DateTime from;
  final DateTime to;
  final int opening;
  final int closing;
  final List<StatementLine> lines;

  /// For a customer (they owe us): positive means they owe us.
  /// For a supplier (we owe them): positive means we owe them.
  factory PartyStatement.fromJson(Map<String, dynamic> json) => PartyStatement(
    partyType: json['party_type'] as String,
    partyId: json['party_id'] as String,
    from: DateTime.parse(json['from'] as String),
    to: DateTime.parse(json['to'] as String),
    opening: (json['opening'] as num?)?.toInt() ?? 0,
    closing: (json['closing'] as num?)?.toInt() ?? 0,
    lines: [
      for (final l in (json['lines'] as List?) ?? const [])
        if (l is Map<String, dynamic>) StatementLine.fromJson(l),
    ],
  );
}
