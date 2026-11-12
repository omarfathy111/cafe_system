import 'package:cafe_system/models/default_cafe_products.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class CafeDatabaseSchema {
  Future<void> createSchema(Database db, int version) async {
    await db.execute('''CREATE TABLE cafe_settings (
      setting_key TEXT PRIMARY KEY,
      setting_value TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE cafe_orders (
      id TEXT PRIMARY KEY,
      label TEXT NOT NULL,
      table_number INTEGER,
      room_number INTEGER,
      is_takeaway INTEGER NOT NULL DEFAULT 0,
      note TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL,
      room_started_at TEXT,
      room_ended_at TEXT,
      room_pricing_mode TEXT,
      room_price REAL,
      status TEXT NOT NULL DEFAULT 'open'
    )''');
    await db.execute('''CREATE UNIQUE INDEX one_open_order_per_table
      ON cafe_orders(table_number) WHERE table_number IS NOT NULL AND status = 'open'
    ''');
    await db.execute('''CREATE UNIQUE INDEX one_open_order_per_room
      ON cafe_orders(room_number) WHERE room_number IS NOT NULL AND status = 'open'
    ''');
    await db.execute('''CREATE TABLE cafe_products (
      product_name TEXT PRIMARY KEY,
      category TEXT NOT NULL,
      unit_price REAL NOT NULL,
      stock_units INTEGER,
      units_per_carton INTEGER,
      purchase_price_per_carton REAL,
      is_active INTEGER NOT NULL DEFAULT 1
    )''');
    await db.execute('''CREATE TABLE cafe_order_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      order_id TEXT NOT NULL,
      product_name TEXT NOT NULL,
      quantity INTEGER NOT NULL CHECK(quantity > 0),
      unit_price REAL NOT NULL,
      discount_per_unit REAL NOT NULL DEFAULT 0,
      FOREIGN KEY(order_id) REFERENCES cafe_orders(id) ON DELETE CASCADE,
      FOREIGN KEY(product_name) REFERENCES cafe_products(product_name)
    )''');
    await db.execute('''CREATE TABLE cafe_sales (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      label TEXT NOT NULL,
      total REAL NOT NULL,
      paid_at TEXT NOT NULL,
      note TEXT NOT NULL DEFAULT '',
      room_charge REAL NOT NULL DEFAULT 0,
      room_minutes INTEGER NOT NULL DEFAULT 0,
      room_started_at TEXT,
      room_ended_at TEXT
    )''');
    await db.execute('''CREATE TABLE cafe_sale_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      sale_id INTEGER NOT NULL,
      product_name TEXT NOT NULL,
      quantity INTEGER NOT NULL,
      unit_price REAL NOT NULL,
      discount_per_unit REAL NOT NULL DEFAULT 0,
      FOREIGN KEY(sale_id) REFERENCES cafe_sales(id) ON DELETE CASCADE,
      FOREIGN KEY(product_name) REFERENCES cafe_products(product_name)
    )''');
    await _createRoomSessionTables(db);
    await _createDailyClosingsTable(db);
    await _createExpensesTable(db);
    await _createNotesTable(db);
    await _createCategoriesTable(db);
    for (final product in cafeProducts) {
      await db.insert('cafe_products', {
        'product_name': product.name,
        'category': product.category,
        'unit_price': product.price,
      });
    }
    await db.insert('cafe_settings', {
      'setting_key': 'table_count',
      'setting_value': '16',
    });
    await _insertDefaultRoomRates(db);
  }

  Future<void> upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _addColumnIfMissing(db, 'cafe_orders', 'room_number', 'INTEGER');
      await db.execute('''CREATE UNIQUE INDEX one_open_order_per_room
        ON cafe_orders(room_number) WHERE room_number IS NOT NULL AND status = 'open'
      ''');
    }
    if (oldVersion < 3) {
      await _addColumnIfMissing(
        db,
        'cafe_products',
        'components',
        "TEXT NOT NULL DEFAULT '[]'",
      );
      await _addColumnIfMissing(
        db,
        'cafe_sale_items',
        'removed_components',
        "TEXT NOT NULL DEFAULT '[]'",
      );
      await db.execute('''CREATE TABLE cafe_order_items_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id TEXT NOT NULL,
        product_name TEXT NOT NULL,
        quantity INTEGER NOT NULL CHECK(quantity > 0),
        unit_price REAL NOT NULL,
        removed_components TEXT NOT NULL DEFAULT '[]',
        FOREIGN KEY(order_id) REFERENCES cafe_orders(id) ON DELETE CASCADE,
        FOREIGN KEY(product_name) REFERENCES cafe_products(product_name)
      )''');
      await db.execute('''INSERT INTO cafe_order_items_new (id, order_id, product_name, quantity, unit_price)
        SELECT id, order_id, product_name, quantity, unit_price FROM cafe_order_items
      ''');
      await db.execute('DROP TABLE cafe_order_items');
      await db.execute(
        'ALTER TABLE cafe_order_items_new RENAME TO cafe_order_items',
      );
      for (final product in cafeProducts) {
        await db.insert('cafe_products', {
          'product_name': product.name,
          'category': product.category,
          'unit_price': product.price,
          'components': '[]',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        await db.update(
          'cafe_products',
          {'components': '[]'},
          where: 'product_name = ?',
          whereArgs: [product.name],
        );
      }
    }
    if (oldVersion < 6) {
      await db.update(
        'cafe_products',
        {'is_active': 0},
        where: 'category IN (?, ?)',
        whereArgs: ['حلويات', 'مخبوزات'],
      );
    }
    if (oldVersion < 7) await _createDailyClosingsTable(db);
    if (oldVersion < 8) {
      await db.execute('DROP TABLE IF EXISTS cafe_sale_ingredients');
      await db.execute('DROP TABLE IF EXISTS cafe_product_recipes');
      await db.execute('DROP TABLE IF EXISTS cafe_ingredients');
      await db.execute("UPDATE cafe_products SET components = '[]'");
      await db.execute("UPDATE cafe_order_items SET removed_components = '[]'");
      await db.execute("UPDATE cafe_sale_items SET removed_components = '[]'");
    }
    if (oldVersion < 9) {
      await _addColumnIfMissing(db, 'cafe_orders', 'room_started_at', 'TEXT');
      await _addColumnIfMissing(db, 'cafe_orders', 'room_ended_at', 'TEXT');
      await _addColumnIfMissing(db, 'cafe_orders', 'room_pricing_mode', 'TEXT');
      await _addColumnIfMissing(db, 'cafe_orders', 'room_price', 'REAL');
      await _addColumnIfMissing(
        db,
        'cafe_sales',
        'room_charge',
        'REAL NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(
        db,
        'cafe_sales',
        'room_minutes',
        'INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 10) {
      await _addColumnIfMissing(db, 'cafe_sales', 'room_started_at', 'TEXT');
      await _addColumnIfMissing(db, 'cafe_sales', 'room_ended_at', 'TEXT');
      await db.update(
        'cafe_products',
        {'is_active': 1},
        where: 'category IN (?, ?)',
        whereArgs: ['حلويات', 'أكلات'],
      );
    }
    if (oldVersion < 11) {
      final hasDailyClosings = await _tableExists(db, 'cafe_daily_closings');
      if (hasDailyClosings) {
        await db.execute(
          'ALTER TABLE cafe_daily_closings RENAME TO cafe_daily_closings_old',
        );
        await _createDailyClosingsTable(db);
        await db.execute(
          '''INSERT INTO cafe_daily_closings (date_key, total, invoice_count, closed_at)
          SELECT date_key, total, invoice_count, closed_at FROM cafe_daily_closings_old''',
        );
        await db.execute('DROP TABLE cafe_daily_closings_old');
      } else {
        await _createDailyClosingsTable(db);
      }
    }
    if (oldVersion < 12) {
      await _addColumnIfMissing(
        db,
        'cafe_order_items',
        'discount_per_unit',
        'REAL NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(
        db,
        'cafe_sale_items',
        'discount_per_unit',
        'REAL NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 13) {
      await _createRoomSessionTables(db);
      await db.execute('''
        INSERT OR IGNORE INTO cafe_order_room_sessions
          (id, order_id, mode, hourly_rate, fixed_charge, started_at, ended_at)
        SELECT
          'legacy-' || id,
          id,
          'single',
          CASE WHEN room_pricing_mode = 'hourly' THEN COALESCE(room_price, 40) ELSE 40 END,
          CASE WHEN room_pricing_mode = 'fixed' THEN room_price ELSE NULL END,
          room_started_at,
          room_ended_at
        FROM cafe_orders
        WHERE room_started_at IS NOT NULL
      ''');
      await _insertDefaultRoomRates(db);
    }
    if (oldVersion < 14) {
      await _addColumnIfMissing(db, 'cafe_products', 'stock_units', 'INTEGER');
      await _addColumnIfMissing(
        db,
        'cafe_products',
        'units_per_carton',
        'INTEGER',
      );
      await _addColumnIfMissing(
        db,
        'cafe_products',
        'purchase_price_per_carton',
        'REAL',
      );
    }
    if (oldVersion < 15) {
      await db.update(
        'cafe_products',
        {'category': 'سناكس'},
        where: "product_name LIKE ? OR product_name LIKE ?",
        whereArgs: ['%شيبسي%', '%شيبس%'],
      );
    }
    if (oldVersion < 16) {
      await _addColumnIfMissing(
        db,
        'cafe_order_room_sessions',
        'discount',
        'REAL NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(
        db,
        'cafe_sale_room_sessions',
        'discount',
        'REAL NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 17) await _createExpensesTable(db);
    if (oldVersion < 18) {
      await _addColumnIfMissing(
        db,
        'cafe_orders',
        'note',
        "TEXT NOT NULL DEFAULT ''",
      );
      await _addColumnIfMissing(
        db,
        'cafe_sales',
        'note',
        "TEXT NOT NULL DEFAULT ''",
      );
      await _migrateSavedTableNotes(db);
    }
    if (oldVersion < 19) {
      await _createNotesTable(db);
      final oldNoteRows = await db.query(
        'cafe_settings',
        columns: ['setting_value'],
        where: 'setting_key = ?',
        whereArgs: ['backup_note'],
        limit: 1,
      );
      if (oldNoteRows.isNotEmpty) {
        final oldNote =
            (oldNoteRows.first['setting_value'] as String?)?.trim() ?? '';
        if (oldNote.isNotEmpty) {
          await db.insert('cafe_notes', {
            'note_text': oldNote,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
        await db.delete(
          'cafe_settings',
          where: 'setting_key = ?',
          whereArgs: ['backup_note'],
        );
      }
    }
    if (oldVersion < 20) {
      await _createCategoriesTable(db);
      await db.execute('''
        INSERT OR IGNORE INTO cafe_categories (category_name)
        SELECT DISTINCT category FROM cafe_products WHERE TRIM(category) != ''
      ''');
      await db.execute('''
        UPDATE cafe_products SET stock_units = stock_units - COALESCE((
          SELECT SUM(i.quantity) FROM cafe_order_items i
          JOIN cafe_orders o ON o.id = i.order_id
          WHERE o.status = 'open' AND i.product_name = cafe_products.product_name
        ), 0)
        WHERE stock_units IS NOT NULL
      ''');
    }
  }

  Future<void> _migrateSavedTableNotes(DatabaseExecutor db) async {
    final rows = await db.query(
      'cafe_settings',
      where: "setting_key LIKE 'place_note_table_%'",
    );
    for (final row in rows) {
      final key = row['setting_key'] as String;
      final tableNumber = int.tryParse(
        key.substring('place_note_table_'.length),
      );
      if (tableNumber != null) {
        await db.update(
          'cafe_orders',
          {'note': row['setting_value'] as String},
          where: "table_number = ? AND status = 'open'",
          whereArgs: [tableNumber],
        );
      }
      await db.delete(
        'cafe_settings',
        where: 'setting_key = ?',
        whereArgs: [key],
      );
    }
  }

  Future<void> _createRoomSessionTables(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS cafe_order_room_sessions (
      id TEXT PRIMARY KEY,
      order_id TEXT NOT NULL,
      mode TEXT NOT NULL,
      hourly_rate REAL NOT NULL,
      fixed_charge REAL,
      discount REAL NOT NULL DEFAULT 0,
      started_at TEXT NOT NULL,
      ended_at TEXT,
      FOREIGN KEY(order_id) REFERENCES cafe_orders(id) ON DELETE CASCADE
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS cafe_sale_room_sessions (
      id TEXT PRIMARY KEY,
      sale_id INTEGER NOT NULL,
      mode TEXT NOT NULL,
      hourly_rate REAL NOT NULL,
      fixed_charge REAL,
      discount REAL NOT NULL DEFAULT 0,
      started_at TEXT NOT NULL,
      ended_at TEXT NOT NULL,
      FOREIGN KEY(sale_id) REFERENCES cafe_sales(id) ON DELETE CASCADE
    )''');
  }

  Future<void> _insertDefaultRoomRates(DatabaseExecutor db) async {
    for (var room = 1; room <= 2; room++) {
      for (final mode in ['single', 'multi']) {
        await db.insert('cafe_settings', {
          'setting_key': 'room_${room}_$mode',
          'setting_value': '40',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
  }

  Future<void> _createDailyClosingsTable(DatabaseExecutor db) => db.execute('''
    CREATE TABLE IF NOT EXISTS cafe_daily_closings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date_key TEXT NOT NULL,
      total REAL NOT NULL,
      invoice_count INTEGER NOT NULL,
      closed_at TEXT NOT NULL
    )
  ''');

  Future<void> _createExpensesTable(DatabaseExecutor db) => db.execute('''
    CREATE TABLE IF NOT EXISTS cafe_expenses (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      amount REAL NOT NULL CHECK(amount > 0),
      note TEXT NOT NULL,
      incurred_at TEXT NOT NULL
    )
  ''');

  Future<void> _createNotesTable(DatabaseExecutor db) => db.execute('''
    CREATE TABLE IF NOT EXISTS cafe_notes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      note_text TEXT NOT NULL,
      created_at TEXT NOT NULL
    )
  ''');

  Future<void> _createCategoriesTable(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS cafe_categories (
      category_name TEXT PRIMARY KEY
    )''');
    for (final category in [
      'مشروبات ساخنة',
      'قهوة',
      'مشروبات باردة',
      'عصائر',
      'شيشة',
      'سناكس',
      'حلويات',
      'أكلات',
    ]) {
      await db.insert('cafe_categories', {
        'category_name': category,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<bool> _tableExists(DatabaseExecutor db, String tableName) async {
    final result = await db.rawQuery(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
      [tableName],
    );
    return result.isNotEmpty;
  }

  Future<void> _addColumnIfMissing(
    DatabaseExecutor db,
    String tableName,
    String columnName,
    String columnDefinition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($tableName)');
    if (columns.any((column) => column['name'] == columnName)) return;
    await db.execute(
      'ALTER TABLE $tableName ADD COLUMN $columnName $columnDefinition',
    );
  }

}
