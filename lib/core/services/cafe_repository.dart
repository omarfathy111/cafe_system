import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cafe_system/core/database/app_database.dart';
import 'package:cafe_system/models/cafe_daily_closing.dart';
import 'package:cafe_system/models/cafe_expense.dart';
import 'package:cafe_system/models/cafe_inventory_total.dart';
import 'package:cafe_system/models/cafe_note.dart';
import 'package:cafe_system/models/cafe_order.dart';
import 'package:cafe_system/models/cafe_product.dart';
import 'package:cafe_system/models/cafe_sale.dart';
import 'package:cafe_system/models/cafe_sale_item.dart';
import 'package:cafe_system/models/cafe_snapshot.dart';
import 'package:cafe_system/models/default_cafe_products.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

export 'package:cafe_system/models/cafe_snapshot.dart';

class CafeRepository {
  CafeRepository({CafeDatabase? database})
    : _database = database ?? CafeDatabase.instance;
  final CafeDatabase _database;

  Future<CafeSnapshot> load() async {
    final db = await _database.database;
    await _migrateLegacyJson(db);
    final orders = await db.query(
      'cafe_orders',
      where: 'status = ?',
      whereArgs: ['open'],
      orderBy: 'created_at',
    );
    final sales = await db.query('cafe_sales', orderBy: 'paid_at DESC');
    final orderItemsByOrder = _groupRows(
      await db.query('cafe_order_items'),
      'order_id',
    );
    final roomSessionsByOrder = _groupRows(
      await db.query('cafe_order_room_sessions', orderBy: 'started_at'),
      'order_id',
    );
    final saleItemsBySale = _groupRows(
      await db.query('cafe_sale_items'),
      'sale_id',
    );
    final roomSessionsBySale = _groupRows(
      await db.query('cafe_sale_room_sessions', orderBy: 'started_at'),
      'sale_id',
    );
    final allProductRows = await db.query(
      'cafe_products',
      orderBy: 'category, product_name',
    );
    CafeProduct mapProduct(Map<String, Object?> row) {
      final name = row['product_name'] as String;
      final defaultProduct = cafeProducts
          .where((product) => product.name == name)
          .firstOrNull;
      return CafeProduct(
        name,
        row['category'] as String,
        (row['unit_price'] as num).toDouble(),
        defaultProduct?.icon ?? Icons.local_cafe,
        stockUnits: row['stock_units'] as int?,
        unitsPerCarton: row['units_per_carton'] as int?,
        purchasePricePerCarton: (row['purchase_price_per_carton'] as num?)
            ?.toDouble(),
      );
    }

    final products = allProductRows
        .where((row) => row['is_active'] == 1)
        .map(mapProduct)
        .toList();
    final inventoryProducts = allProductRows
        .where((row) => row['stock_units'] != null)
        .map(mapProduct)
        .toList();
    final dailyClosings = (await db.query(
      'cafe_daily_closings',
      orderBy: 'closed_at DESC',
    )).map(CafeDailyClosing.fromMap).toList();
    final expenses = (await db.query(
      'cafe_expenses',
      orderBy: 'incurred_at DESC',
    )).map(CafeExpense.fromMap).toList();
    final notes = (await db.query(
      'cafe_notes',
      orderBy: 'created_at DESC, id DESC',
    )).map(CafeNote.fromMap).toList();
    final categories = (await db.query(
      'cafe_categories',
      orderBy: 'category_name',
    )).map((row) => row['category_name'] as String).toList();
    final orderModels = <CafeOrder>[];
    for (final row in orders) {
      final id = row['id'] as String;
      final itemModels = <CafeOrderItem>[];
      for (final item in orderItemsByOrder[id] ?? const []) {
        final name = item['product_name'] as String;
        itemModels.add(
          CafeOrderItem(
            productName: name,
            quantity: item['quantity'] as int,
            unitPrice: (item['unit_price'] as num).toDouble(),
            discountPerUnit:
                (item['discount_per_unit'] as num?)?.toDouble() ?? 0,
          ),
        );
      }
      orderModels.add(
        CafeOrder(
          id: id,
          label: row['label'] as String,
          tableNumber: row['table_number'] as int?,
          roomNumber: row['room_number'] as int?,
          isTakeaway: (row['is_takeaway'] as int) == 1,
          note: row['note'] as String? ?? '',
          items: itemModels,
          createdAt:
              DateTime.tryParse(row['created_at'] as String) ?? DateTime.now(),
          roomSessions: (roomSessionsByOrder[id] ?? const [])
              .map(_roomSessionFromMap)
              .toList(),
        ),
      );
    }

    final saleModels = <CafeSale>[];
    for (final row in sales) {
      final id = row['id'] as int;
      final items = saleItemsBySale['$id'] ?? const <Map<String, Object?>>[];
      final summary = <String, int>{};
      for (final item in items) {
        final productName = item['product_name'] as String;
        final discount = (item['discount_per_unit'] as num?)?.toDouble() ?? 0;
        final displayName = discount > 0
            ? '$productName (خصم ${discount.toStringAsFixed(2)} للوحدة)'
            : productName;
        summary.update(
          displayName,
          (quantity) => quantity + (item['quantity'] as int),
          ifAbsent: () => item['quantity'] as int,
        );
      }
      final roomCharge = (row['room_charge'] as num?)?.toDouble() ?? 0;
      final roomSessions = (roomSessionsBySale['$id'] ?? const [])
          .map(_roomSessionFromMap)
          .toList();
      if (roomCharge > 0 && roomSessions.isEmpty) {
        final minutes = row['room_minutes'] as int? ?? 0;
        summary['حجز بلايستيشن (${_formatDuration(minutes)})'] = 1;
      } else {
        for (final session in roomSessions) {
          final sessionEnd = session.endedAt ?? DateTime.now();
          summary.update(
            'بلايستيشن ${session.mode == 'multi' ? 'Multi' : 'Single'} • ${_formatTimestamp(session.startedAt)}-${_formatTimestamp(sessionEnd)} • ${_formatDuration(session.durationMinutesAt(sessionEnd))}${session.discount > 0 ? ' • خصم ${session.discount.toStringAsFixed(2)} ج.م' : ''} • ${session.chargeAt(sessionEnd).toStringAsFixed(2)} ج.م',
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
      }
      saleModels.add(
        CafeSale(
          id: id,
          label: row['label'] as String,
          total: (row['total'] as num).toDouble(),
          time: DateTime.tryParse(row['paid_at'] as String) ?? DateTime.now(),
          items: summary,
          roomSessions: roomSessions,
          roomCharge: (row['room_charge'] as num?)?.toDouble() ?? 0,
          roomMinutes: row['room_minutes'] as int? ?? 0,
          roomStartedAt: roomSessions.isEmpty
              ? DateTime.tryParse(row['room_started_at'] as String? ?? '')
              : roomSessions.first.startedAt,
          roomEndedAt: roomSessions.isEmpty
              ? DateTime.tryParse(row['room_ended_at'] as String? ?? '')
              : roomSessions.last.endedAt,
          note: row['note'] as String? ?? '',
          saleItems: [
            for (final item in items)
              CafeSaleItem(
                productName: item['product_name'] as String,
                quantity: item['quantity'] as int,
                unitPrice: (item['unit_price'] as num).toDouble(),
                discountPerUnit:
                    (item['discount_per_unit'] as num?)?.toDouble() ?? 0,
              ),
          ],
        ),
      );
    }
    final settings = await db.query(
      'cafe_settings',
      where: 'setting_key = ?',
      whereArgs: ['table_count'],
      limit: 1,
    );
    final tableCount = settings.isEmpty
        ? 16
        : int.tryParse(settings.first['setting_value'] as String) ?? 16;
    final rateRows = await db.query(
      'cafe_settings',
      where: "setting_key LIKE 'room_%'",
    );
    final roomHourlyRates = <String, double>{
      for (var room = 1; room <= 2; room++)
        for (final mode in ['single', 'multi']) 'room_${room}_$mode': 40,
    };
    for (final row in rateRows) {
      final key = row['setting_key'] as String;
      final value = double.tryParse(row['setting_value'] as String);
      if (value != null && value > 0) roomHourlyRates[key] = value;
    }
    final nameRows = await db.query(
      'cafe_settings',
      where: "setting_key LIKE 'place_name_%'",
    );
    final placeNames = <String, String>{
      for (final row in nameRows)
        (row['setting_key'] as String).substring('place_name_'.length):
            row['setting_value'] as String,
    };
    return CafeSnapshot(
      orders: orderModels,
      sales: saleModels,
      products: products,
      inventoryProducts: inventoryProducts,
      tableCount: tableCount,
      roomHourlyRates: roomHourlyRates,
      dailyClosings: dailyClosings,
      expenses: expenses,
      placeNames: placeNames,
      notes: notes,
      categories: categories,
    );
  }

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

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
  }

  String _formatTimestamp(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';

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

  Future<void> setProductActive(String name, bool active) async {
    final db = await _database.database;
    await db.update(
      'cafe_products',
      {'is_active': active ? 1 : 0},
      where: 'product_name = ?',
      whereArgs: [name],
    );
  }

  Future<File> createBackup() => _database.createBackup();

  Future<List<File>> listBackups() => _database.listBackups();

  Future<void> restoreBackup(File backup) => _database.restoreBackup(backup);

  Future<CafeNote> addNote(String note) async {
    final text = note.trim();
    if (text.isEmpty) throw ArgumentError('اكتب الملاحظة أولًا');
    final db = await _database.database;
    final createdAt = DateTime.now();
    final id = await db.insert('cafe_notes', {
      'note_text': text,
      'created_at': createdAt.toIso8601String(),
    });
    return CafeNote(id: id, text: text, createdAt: createdAt);
  }

  String get backupsDirectoryPath => _database.backupsDirectoryPath;

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

  Map<String, List<Map<String, Object?>>> _groupRows(
    List<Map<String, Object?>> rows,
    String column,
  ) {
    final grouped = <String, List<Map<String, Object?>>>{};
    for (final row in rows) {
      final key = row[column].toString();
      grouped.putIfAbsent(key, () => []).add(row);
    }
    return grouped;
  }

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

  CafeRoomSession _roomSessionFromMap(Map<String, Object?> row) =>
      CafeRoomSession(
        id: row['id'] as String,
        mode: row['mode'] as String,
        hourlyRate: (row['hourly_rate'] as num).toDouble(),
        legacyFixedCharge: (row['fixed_charge'] as num?)?.toDouble(),
        discount: (row['discount'] as num?)?.toDouble() ?? 0,
        startedAt:
            DateTime.tryParse(row['started_at'] as String) ?? DateTime.now(),
        endedAt: DateTime.tryParse(row['ended_at'] as String? ?? ''),
      );

  Future<void> _migrateLegacyJson(Database db) async {
    final migrated = await db.query(
      'cafe_settings',
      where: 'setting_key = ?',
      whereArgs: ['legacy_json_migrated'],
      limit: 1,
    );
    if (migrated.isNotEmpty) return;

    final appData =
        Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['APPDATA'] ??
        Directory.current.path;
    final oldFile = File(path.join(appData, 'CafeSystem', 'cafe_data.json'));
    if (await oldFile.exists()) {
      try {
        final data =
            jsonDecode(await oldFile.readAsString()) as Map<String, dynamic>;
        await db.transaction((txn) async {
          final tableCount = data['tableCount'] as int? ?? 16;
          await txn.insert('cafe_settings', {
            'setting_key': 'table_count',
            'setting_value': '$tableCount',
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          for (final raw in (data['orders'] as List? ?? [])) {
            final order = Map<String, dynamic>.from(raw as Map);
            final orderId = order['id'] as String;
            await txn.insert('cafe_orders', {
              'id': orderId,
              'label': order['label'] as String,
              'table_number': order['tableNumber'] as int?,
              'room_number': order['roomNumber'] as int?,
              'is_takeaway': (order['isTakeaway'] as bool? ?? false) ? 1 : 0,
              'created_at':
                  order['createdAt'] as String? ??
                  DateTime.now().toIso8601String(),
              'status': 'open',
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
            final rawItems = order['items'];
            final items = rawItems is Map
                ? Map<String, dynamic>.from(rawItems)
                : <String, dynamic>{};
            for (final item in items.entries) {
              final product = cafeProducts
                  .where((p) => p.name == item.key)
                  .firstOrNull;
              if (product == null) continue;
              await txn.insert('cafe_order_items', {
                'order_id': orderId,
                'product_name': item.key,
                'quantity': item.value as int,
                'unit_price': product.price,
              }, conflictAlgorithm: ConflictAlgorithm.ignore);
            }
          }
          for (final raw in (data['sales'] as List? ?? [])) {
            final sale = Map<String, dynamic>.from(raw as Map);
            final saleId = await txn.insert('cafe_sales', {
              'label': sale['label'] as String,
              'total': (sale['total'] as num).toDouble(),
              'paid_at':
                  sale['time'] as String? ?? DateTime.now().toIso8601String(),
            });
            final items = Map<String, dynamic>.from(
              sale['items'] as Map? ?? {},
            );
            for (final item in items.entries) {
              final product = cafeProducts
                  .where((p) => p.name == item.key)
                  .firstOrNull;
              if (product == null) continue;
              await txn.insert('cafe_sale_items', {
                'sale_id': saleId,
                'product_name': item.key,
                'quantity': item.value as int,
                'unit_price': product.price,
              });
            }
          }
          await txn.insert('cafe_settings', {
            'setting_key': 'legacy_json_migrated',
            'setting_value': '1',
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        });
      } catch (_) {
        // Retain the original JSON file if any row cannot be migrated safely.
        rethrow;
      }
    }
    if (!await oldFile.exists()) {
      await db.insert('cafe_settings', {
        'setting_key': 'legacy_json_migrated',
        'setting_value': '1',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    if (await oldFile.exists()) {
      final backup = File('${oldFile.path}.migrated.bak');
      if (!await backup.exists()) await oldFile.rename(backup.path);
    }
  }
}
