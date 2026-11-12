part of 'cafe_repository.dart';

extension CafeRepositoryAuth on CafeRepository {
  Future<void> initializeDefaultAdminPasswordOnce() async {
    final db = await _database.database;
    await db.transaction((txn) async {
      final marker = await txn.query(
        'cafe_settings',
        columns: ['setting_value'],
        where: 'setting_key = ?',
        whereArgs: ['admin_password_default_eslam1995_v1'],
        limit: 1,
      );
      if (marker.isNotEmpty) return;

      const password = 'eslam1995';
      final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
      final hash = sha256.convert([
        ...salt,
        ...utf8.encode(password),
      ]).toString();
      await txn.insert('cafe_settings', {
        'setting_key': 'admin_password_hash',
        'setting_value': '${base64Encode(salt)}:$hash',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('cafe_settings', {
        'setting_key': 'admin_password_default_eslam1995_v1',
        'setting_value': '1',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<bool> hasAdminPassword() async {
    final rows = await (await _database.database).query(
      'cafe_settings',
      columns: ['setting_value'],
      where: 'setting_key = ?',
      whereArgs: ['admin_password_hash'],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> setAdminPassword(String password) async {
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final hash = sha256.convert([...salt, ...utf8.encode(password)]).toString();
    final value = '${base64Encode(salt)}:$hash';
    final db = await _database.database;
    await db.insert('cafe_settings', {
      'setting_key': 'admin_password_hash',
      'setting_value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<bool> verifyAdminPassword(String password) async {
    final rows = await (await _database.database).query(
      'cafe_settings',
      columns: ['setting_value'],
      where: 'setting_key = ?',
      whereArgs: ['admin_password_hash'],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    final parts = (rows.first['setting_value'] as String).split(':');
    if (parts.length != 2) return false;
    final salt = base64Decode(parts.first);
    final candidate = sha256.convert([
      ...salt,
      ...utf8.encode(password),
    ]).toString();
    return candidate == parts.last;
  }

}
