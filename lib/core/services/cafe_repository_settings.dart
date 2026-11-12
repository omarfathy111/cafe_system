part of 'cafe_repository.dart';

extension CafeRepositorySettings on CafeRepository {
  Future<void> setTableCount(int count) async {
    if (count < 1) {
      throw ArgumentError.value(
        count,
        'count',
        'يجب وجود ترابيزة واحدة على الأقل',
      );
    }
    final db = await _database.database;
    await db.insert('cafe_settings', {
      'setting_key': 'table_count',
      'setting_value': '$count',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveRoomHourlyRate(
    int roomNumber,
    String mode,
    double rate,
  ) async {
    if (!rate.isFinite || rate <= 0) {
      throw ArgumentError('سعر الساعة غير صالح');
    }
    final db = await _database.database;
    await db.insert('cafe_settings', {
      'setting_key': 'room_${roomNumber}_$mode',
      'setting_value': rate.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> savePlaceName({
    required bool isRoom,
    required int number,
    required String name,
  }) async {
    if (number < 1 || (!isRoom && number > 1000) || (isRoom && number > 2)) {
      throw ArgumentError('رقم المكان غير صالح');
    }
    final db = await _database.database;
    final key = 'place_name_${isRoom ? 'room' : 'table'}_$number';
    final value = name.trim();
    if (value.isEmpty) {
      await db.delete(
        'cafe_settings',
        where: 'setting_key = ?',
        whereArgs: [key],
      );
      return;
    }
    await db.insert('cafe_settings', {
      'setting_key': key,
      'setting_value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

}
