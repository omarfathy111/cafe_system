part of 'cafe_repository.dart';

extension CafeRepositoryOrders on CafeRepository {
  Future<void> saveOrder(CafeOrder order) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      final oldItems = await txn.query(
        'cafe_order_items',
        columns: ['product_name', 'quantity'],
        where: 'order_id = ?',
        whereArgs: [order.id],
      );
      final oldQuantities = <String, int>{};
      for (final row in oldItems) {
        final name = row['product_name'] as String;
        oldQuantities.update(
          name,
          (value) => value + (row['quantity'] as int),
          ifAbsent: () => row['quantity'] as int,
        );
      }
      final newQuantities = <String, int>{};
      for (final item in order.items) {
        newQuantities.update(
          item.productName,
          (value) => value + item.quantity,
          ifAbsent: () => item.quantity,
        );
      }
      for (final name in {...oldQuantities.keys, ...newQuantities.keys}) {
        final delta = (newQuantities[name] ?? 0) - (oldQuantities[name] ?? 0);
        if (delta == 0) continue;
        final rows = await txn.query(
          'cafe_products',
          columns: ['stock_units'],
          where: 'product_name = ?',
          whereArgs: [name],
          limit: 1,
        );
        if (rows.isEmpty || rows.first['stock_units'] == null) continue;
        final available = rows.first['stock_units'] as int;
        if (delta > 0 && available < delta) {
          throw StateError('الكمية المتاحة من $name هي $available فقط');
        }
        await txn.rawUpdate(
          'UPDATE cafe_products SET stock_units = stock_units - ? WHERE product_name = ?',
          [delta, name],
        );
      }
      await txn.insert('cafe_orders', {
        'id': order.id,
        'label': order.label,
        'table_number': order.tableNumber,
        'room_number': order.roomNumber,
        'is_takeaway': order.isTakeaway ? 1 : 0,
        'note': order.note,
        'created_at': order.createdAt.toIso8601String(),
        'room_started_at': order.roomStartedAt?.toIso8601String(),
        'room_ended_at': order.roomEndedAt?.toIso8601String(),
        'room_pricing_mode': order.roomPricingMode,
        'room_price': order.roomPrice,
        'status': 'open',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete(
        'cafe_order_room_sessions',
        where: 'order_id = ?',
        whereArgs: [order.id],
      );
      for (final session in order.roomSessions) {
        await txn.insert('cafe_order_room_sessions', {
          'id': session.id,
          'order_id': order.id,
          'mode': session.mode,
          'hourly_rate': session.hourlyRate,
          'fixed_charge': session.legacyFixedCharge,
          'discount': session.discount,
          'started_at': session.startedAt.toIso8601String(),
          'ended_at': session.endedAt?.toIso8601String(),
        });
      }
      await txn.delete(
        'cafe_order_items',
        where: 'order_id = ?',
        whereArgs: [order.id],
      );
      for (final item in order.items) {
        final product = await txn.query(
          'cafe_products',
          columns: ['unit_price'],
          where: 'product_name = ? AND is_active = 1',
          whereArgs: [item.productName],
          limit: 1,
        );
        final catalogPrice = product.isEmpty
            ? null
            : (product.first['unit_price'] as num).toDouble();
        final price = item.unitPrice > 0 ? item.unitPrice : catalogPrice;
        if (price == null || item.quantity <= 0) continue;
        await txn.insert('cafe_order_items', {
          'order_id': order.id,
          'product_name': item.productName,
          'quantity': item.quantity,
          'unit_price': price,
          'discount_per_unit': item.discountPerUnit,
        });
      }
    });
  }

  Future<int> completeSale(CafeOrder order) async {
    final db = await _database.database;
    return db.transaction<int>((txn) async {
      final now = DateTime.now();
      final saleId = await txn.insert('cafe_sales', {
        'label': order.label,
        'total': order.total,
        'paid_at': now.toIso8601String(),
        'note': order.note,
        'room_charge': order.roomCharge,
        'room_minutes': order.roomDurationMinutesAt(now),
        'room_started_at': order.roomStartedAt?.toIso8601String(),
        'room_ended_at': order.roomEndedAt?.toIso8601String(),
      });
      for (final session in order.roomSessions) {
        await txn.insert('cafe_sale_room_sessions', {
          'id': session.id,
          'sale_id': saleId,
          'mode': session.mode,
          'hourly_rate': session.hourlyRate,
          'fixed_charge': session.legacyFixedCharge,
          'discount': session.discount,
          'started_at': session.startedAt.toIso8601String(),
          'ended_at': (session.endedAt ?? now).toIso8601String(),
        });
      }
      for (final item in order.items) {
        final product = await txn.query(
          'cafe_products',
          columns: ['unit_price'],
          where: 'product_name = ?',
          whereArgs: [item.productName],
          limit: 1,
        );
        final catalogPrice = product.isEmpty
            ? null
            : (product.first['unit_price'] as num).toDouble();
        final price = item.unitPrice > 0 ? item.unitPrice : catalogPrice;
        if (price == null) continue;
        await txn.insert('cafe_sale_items', {
          'sale_id': saleId,
          'product_name': item.productName,
          'quantity': item.quantity,
          'unit_price': price,
          'discount_per_unit': item.discountPerUnit,
        });
      }
      await txn.delete('cafe_orders', where: 'id = ?', whereArgs: [order.id]);
      return saleId;
    });
  }

  Future<void> updateSale({
    required int id,
    required List<CafeSaleItem> items,
    required String note,
  }) async {
    if (items.any(
      (item) =>
          item.quantity <= 0 ||
          !item.unitPrice.isFinite ||
          item.unitPrice < item.discountPerUnit,
    )) {
      throw ArgumentError('تفاصيل أصناف الفاتورة غير صالحة');
    }
    final db = await _database.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'cafe_sales',
        columns: ['total', 'paid_at', 'room_charge'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('الفاتورة غير موجودة');
      final oldTotal = (rows.first['total'] as num).toDouble();
      final paidAt = rows.first['paid_at'] as String;
      final roomCharge = (rows.first['room_charge'] as num?)?.toDouble() ?? 0;
      final newTotal =
          roomCharge + items.fold<double>(0, (sum, item) => sum + item.total);

      final oldRows = await txn.query(
        'cafe_sale_items',
        columns: ['product_name', 'quantity'],
        where: 'sale_id = ?',
        whereArgs: [id],
      );
      final oldQuantities = <String, int>{};
      for (final row in oldRows) {
        final name = row['product_name'] as String;
        oldQuantities.update(
          name,
          (value) => value + (row['quantity'] as int),
          ifAbsent: () => row['quantity'] as int,
        );
      }
      final newQuantities = <String, int>{};
      for (final item in items) {
        newQuantities.update(
          item.productName,
          (value) => value + item.quantity,
          ifAbsent: () => item.quantity,
        );
      }
      for (final name in {...oldQuantities.keys, ...newQuantities.keys}) {
        final delta = (newQuantities[name] ?? 0) - (oldQuantities[name] ?? 0);
        if (delta == 0) continue;
        final productRows = await txn.query(
          'cafe_products',
          columns: ['stock_units'],
          where: 'product_name = ?',
          whereArgs: [name],
          limit: 1,
        );
        if (productRows.isEmpty || productRows.first['stock_units'] == null) {
          continue;
        }
        final available = productRows.first['stock_units'] as int;
        if (delta > 0 && available < delta) {
          throw StateError('الكمية المتاحة من $name هي $available فقط');
        }
        await txn.rawUpdate(
          'UPDATE cafe_products SET stock_units = stock_units - ? WHERE product_name = ?',
          [delta, name],
        );
      }

      await txn.delete(
        'cafe_sale_items',
        where: 'sale_id = ?',
        whereArgs: [id],
      );
      for (final item in items) {
        await txn.insert('cafe_sale_items', {
          'sale_id': id,
          'product_name': item.productName,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'discount_per_unit': item.discountPerUnit,
        });
      }
      await txn.update(
        'cafe_sales',
        {'total': newTotal, 'note': note.trim()},
        where: 'id = ?',
        whereArgs: [id],
      );
      final delta = newTotal - oldTotal;
      if (delta != 0) {
        await txn.rawUpdate(
          '''UPDATE cafe_daily_closings SET total = total + ?
          WHERE id = (SELECT id FROM cafe_daily_closings
            WHERE date_key = substr(?, 1, 10) AND closed_at >= ?
            ORDER BY closed_at ASC LIMIT 1)''',
          [delta, paidAt, paidAt],
        );
      }
    });
  }

  Future<void> deleteSale(int id) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      final sales = await txn.query(
        'cafe_sales',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (sales.isEmpty) return;
      final total = (sales.first['total'] as num).toDouble();
      final paidAt = sales.first['paid_at'] as String;
      final items = await txn.query(
        'cafe_sale_items',
        where: 'sale_id = ?',
        whereArgs: [id],
      );
      for (final item in items) {
        final name = item['product_name'] as String;
        final quantity = item['quantity'] as int;
        await txn.rawUpdate(
          '''UPDATE cafe_products SET stock_units = stock_units + ?
          WHERE product_name = ? AND stock_units IS NOT NULL''',
          [quantity, name],
        );
      }
      await txn.rawUpdate(
        '''UPDATE cafe_daily_closings
        SET total = total - ?, invoice_count = MAX(0, invoice_count - 1)
        WHERE id = (SELECT id FROM cafe_daily_closings
          WHERE date_key = substr(?, 1, 10) AND closed_at >= ?
          ORDER BY closed_at ASC LIMIT 1)''',
        [total, paidAt, paidAt],
      );
      await txn.delete('cafe_sales', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> cancelRoomBooking(CafeOrder order) async {
    if (order.roomNumber == null || order.items.isNotEmpty) {
      throw StateError('لا يمكن إلغاء حجز يحتوي على أصناف');
    }
    final db = await _database.database;
    await db.transaction((txn) async {
      final storedItems = await txn.query(
        'cafe_order_items',
        columns: ['id'],
        where: 'order_id = ?',
        whereArgs: [order.id],
        limit: 1,
      );
      if (storedItems.isNotEmpty) {
        throw StateError('احصل حساب الأصناف قبل إلغاء حجز الأوضة');
      }
      await txn.delete(
        'cafe_orders',
        where: 'id = ? AND room_number IS NOT NULL AND status = ?',
        whereArgs: [order.id, 'open'],
      );
    });
  }

}
