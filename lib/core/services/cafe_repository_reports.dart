part of 'cafe_repository.dart';

extension CafeRepositoryReports on CafeRepository {
  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<CafeDailyClosing> closeDaily(DateTime date) async {
    final db = await _database.database;
    final dateKey = _dateKey(date);
    return db.transaction((txn) async {
      final previousClosing = await txn.query(
        'cafe_daily_closings',
        where: 'date_key = ?',
        whereArgs: [dateKey],
        orderBy: 'closed_at DESC',
        limit: 1,
      );
      final closedAt = DateTime.now();
      final previousClosedAt = previousClosing.isEmpty
          ? null
          : DateTime.parse(previousClosing.first['closed_at'] as String);
      final where = previousClosedAt == null
          ? 'substr(paid_at, 1, 10) = ? AND paid_at <= ?'
          : 'substr(paid_at, 1, 10) = ? AND paid_at > ? AND paid_at <= ?';
      final whereArgs = previousClosedAt == null
          ? [dateKey, closedAt.toIso8601String()]
          : [
              dateKey,
              previousClosedAt.toIso8601String(),
              closedAt.toIso8601String(),
            ];
      final sales = await txn.query(
        'cafe_sales',
        columns: ['total'],
        where: where,
        whereArgs: whereArgs,
      );
      final grossSales = sales.fold<double>(
        0,
        (sum, sale) => sum + (sale['total'] as num).toDouble(),
      );
      final expenseWhere = previousClosedAt == null
          ? 'substr(incurred_at, 1, 10) = ? AND incurred_at <= ?'
          : 'substr(incurred_at, 1, 10) = ? AND incurred_at > ? AND incurred_at <= ?';
      final expenseWhereArgs = previousClosedAt == null
          ? [dateKey, closedAt.toIso8601String()]
          : [
              dateKey,
              previousClosedAt.toIso8601String(),
              closedAt.toIso8601String(),
            ];
      final expenses = await txn.query(
        'cafe_expenses',
        columns: ['amount'],
        where: expenseWhere,
        whereArgs: expenseWhereArgs,
      );
      final expenseTotal = expenses.fold<double>(
        0,
        (sum, expense) => sum + (expense['amount'] as num).toDouble(),
      );
      final total = grossSales - expenseTotal;
      final id = await txn.insert('cafe_daily_closings', {
        'date_key': dateKey,
        'total': total,
        'invoice_count': sales.length,
        'closed_at': closedAt.toIso8601String(),
      });
      return CafeDailyClosing(
        id: id,
        dateKey: dateKey,
        total: total,
        invoiceCount: sales.length,
        closedAt: closedAt,
      );
    });
  }

}
