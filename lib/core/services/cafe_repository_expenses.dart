part of 'cafe_repository.dart';

extension CafeRepositoryExpenses on CafeRepository {
  Future<CafeExpense> addExpense({
    required double amount,
    required String note,
  }) async {
    final normalizedNote = note.trim();
    if (!amount.isFinite || amount <= 0 || normalizedNote.isEmpty) {
      throw ArgumentError('أدخل مبلغًا صحيحًا ووصفًا للمصروف');
    }
    final db = await _database.database;
    final incurredAt = DateTime.now();
    final id = await db.insert('cafe_expenses', {
      'amount': amount,
      'note': normalizedNote,
      'incurred_at': incurredAt.toIso8601String(),
    });
    return CafeExpense(
      id: id,
      amount: amount,
      note: normalizedNote,
      incurredAt: incurredAt,
    );
  }

  Future<void> updateExpense({
    required int id,
    required double amount,
    required String note,
  }) async {
    final normalizedNote = note.trim();
    if (!amount.isFinite || amount <= 0 || normalizedNote.isEmpty) {
      throw ArgumentError('أدخل مبلغًا صحيحًا ووصفًا للمصروف');
    }
    final db = await _database.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'cafe_expenses',
        columns: ['amount', 'incurred_at'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('المصروف غير موجود');
      final oldAmount = (rows.first['amount'] as num).toDouble();
      final incurredAt = rows.first['incurred_at'] as String;
      await txn.update(
        'cafe_expenses',
        {'amount': amount, 'note': normalizedNote},
        where: 'id = ?',
        whereArgs: [id],
      );
      final delta = amount - oldAmount;
      if (delta != 0) {
        await txn.rawUpdate(
          '''UPDATE cafe_daily_closings SET total = total - ?
          WHERE id = (SELECT id FROM cafe_daily_closings
            WHERE date_key = substr(?, 1, 10) AND closed_at >= ?
            ORDER BY closed_at ASC LIMIT 1)''',
          [delta, incurredAt, incurredAt],
        );
      }
    });
  }

  Future<void> deleteExpense(int id) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'cafe_expenses',
        columns: ['amount', 'incurred_at'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final amount = (rows.first['amount'] as num).toDouble();
      final incurredAt = rows.first['incurred_at'] as String;
      await txn.rawUpdate(
        '''UPDATE cafe_daily_closings SET total = total + ?
        WHERE id = (SELECT id FROM cafe_daily_closings
          WHERE date_key = substr(?, 1, 10) AND closed_at >= ?
          ORDER BY closed_at ASC LIMIT 1)''',
        [amount, incurredAt, incurredAt],
      );
      await txn.delete('cafe_expenses', where: 'id = ?', whereArgs: [id]);
    });
  }

}
