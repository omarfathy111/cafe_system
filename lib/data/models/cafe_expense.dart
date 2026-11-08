class CafeExpense {
  const CafeExpense({
    required this.id,
    required this.amount,
    required this.note,
    required this.incurredAt,
  });

  final int id;
  final double amount;
  final String note;
  final DateTime incurredAt;

  factory CafeExpense.fromMap(Map<String, Object?> row) => CafeExpense(
    id: row['id'] as int,
    amount: (row['amount'] as num).toDouble(),
    note: row['note'] as String,
    incurredAt: DateTime.parse(row['incurred_at'] as String),
  );
}
