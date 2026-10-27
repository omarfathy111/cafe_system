class CafeDailyClosing {
  const CafeDailyClosing({
    this.id,
    required this.dateKey,
    required this.total,
    required this.invoiceCount,
    required this.closedAt,
  });

  final int? id;
  final String dateKey;
  final double total;
  final int invoiceCount;
  final DateTime closedAt;

  factory CafeDailyClosing.fromMap(Map<String, Object?> row) =>
      CafeDailyClosing(
        id: row['id'] as int?,
        dateKey: row['date_key'] as String,
        total: (row['total'] as num).toDouble(),
        invoiceCount: row['invoice_count'] as int,
        closedAt: DateTime.parse(row['closed_at'] as String),
      );
}
