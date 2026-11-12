part of 'cafe_repository.dart';

extension CafeRepositoryProducts on CafeRepository {
  Future<void> addCategory(String name) async {
    final category = name.trim();
    if (category.isEmpty || category == 'الكل') {
      throw ArgumentError('اكتب اسم قسم صحيح');
    }
    final db = await _database.database;
    await db.insert('cafe_categories', {
      'category_name': category,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<Map<String, CafeInventoryTotal>> loadInventorySales(
    DateTime from,
    DateTime through,
  ) async {
    final db = await _database.database;
    final start = DateTime(from.year, from.month, from.day);
    final endExclusive = DateTime(through.year, through.month, through.day + 1);
    final rows = await db.rawQuery(
      '''SELECT i.product_name,
          SUM(i.quantity) AS quantity,
          SUM(i.quantity * (i.unit_price - COALESCE(i.discount_per_unit, 0))) AS amount
      FROM cafe_sale_items i
      INNER JOIN cafe_sales s ON s.id = i.sale_id
      WHERE s.paid_at >= ? AND s.paid_at < ?
      GROUP BY i.product_name ORDER BY i.product_name''',
      [start.toIso8601String(), endExclusive.toIso8601String()],
    );
    final historicalProducts = await db.query(
      'cafe_products',
      columns: ['product_name', 'units_per_carton'],
    );
    final cartonSizes = {
      for (final row in historicalProducts)
        row['product_name'] as String: row['units_per_carton'] as int?,
    };
    return {
      for (final row in rows)
        row['product_name'] as String: CafeInventoryTotal(
          quantity: (row['quantity'] as num).toInt(),
          amount: (row['amount'] as num?)?.toDouble() ?? 0,
          unitsPerCarton: cartonSizes[row['product_name'] as String],
        ),
    };
  }

  Future<void> restockProduct(
    CafeProduct product,
    int cartons,
    double purchasePrice,
  ) async {
    final unitsPerCarton = product.unitsPerCarton;
    if (!product.tracksStock ||
        unitsPerCarton == null ||
        cartons <= 0 ||
        !purchasePrice.isFinite ||
        purchasePrice <= 0) {
      throw ArgumentError('بيانات الكرتونة غير صالحة');
    }
    final db = await _database.database;
    await db.rawUpdate(
      '''UPDATE cafe_products
      SET stock_units = COALESCE(stock_units, 0) + ?,
          purchase_price_per_carton = ?
      WHERE product_name = ?''',
      [cartons * unitsPerCarton, purchasePrice, product.name],
    );
  }

  Future<void> setProductStock(CafeProduct product, int stockUnits) async {
    if (!product.tracksStock || stockUnits < 0) {
      throw ArgumentError('رصيد المخزون غير صالح');
    }
    final db = await _database.database;
    await db.update(
      'cafe_products',
      {'stock_units': stockUnits},
      where: 'product_name = ? AND stock_units IS NOT NULL',
      whereArgs: [product.name],
    );
  }

  Future<void> saveProduct(CafeProduct product, {String? previousName}) async {
    if (!product.price.isFinite || product.price <= 0) {
      throw ArgumentError('سعر الصنف غير صالح');
    }
    if (product.stockUnits != null &&
        (product.stockUnits! < 0 ||
            product.unitsPerCarton == null ||
            product.unitsPerCarton! <= 0)) {
      throw ArgumentError('بيانات مخزون الصنف غير صالحة');
    }
    final db = await _database.database;
    final values = {
      'category': product.category,
      'unit_price': product.price,
      'stock_units': product.stockUnits,
      'units_per_carton': product.unitsPerCarton,
      'purchase_price_per_carton': product.purchasePricePerCarton,
      'is_active': 1,
    };
    final oldName = previousName?.trim();
    await db.transaction((txn) async {
      if (oldName != null && oldName.isNotEmpty && oldName != product.name) {
        final oldRows = await txn.query(
          'cafe_products',
          where: 'product_name = ?',
          whereArgs: [oldName],
          limit: 1,
        );
        if (oldRows.isEmpty) throw StateError('الصنف القديم غير موجود');
        final newRows = await txn.query(
          'cafe_products',
          columns: ['product_name'],
          where: 'product_name = ?',
          whereArgs: [product.name],
          limit: 1,
        );
        if (newRows.isNotEmpty) throw StateError('يوجد صنف بالاسم الجديد');

        await txn.insert('cafe_products', {
          'product_name': product.name,
          ...values,
        });
        await txn.update(
          'cafe_order_items',
          {'product_name': product.name},
          where: 'product_name = ?',
          whereArgs: [oldName],
        );
        await txn.update(
          'cafe_sale_items',
          {'product_name': product.name},
          where: 'product_name = ?',
          whereArgs: [oldName],
        );
        await txn.delete(
          'cafe_products',
          where: 'product_name = ?',
          whereArgs: [oldName],
        );
        return;
      }

      final existing = await txn.query(
        'cafe_products',
        columns: ['product_name'],
        where: 'product_name = ?',
        whereArgs: [product.name],
        limit: 1,
      );
      if (existing.isEmpty) {
        await txn.insert('cafe_products', {
          'product_name': product.name,
          ...values,
        });
      } else {
        await txn.update(
          'cafe_products',
          values,
          where: 'product_name = ?',
          whereArgs: [product.name],
        );
      }
    });
  }

  Future<void> setProductActive(String name, bool active) async {
    final db = await _database.database;
    await db.update(
      'cafe_products',
      {'is_active': active ? 1 : 0},
      where: 'product_name = ?',
      whereArgs: [name],
    );
  }

}
