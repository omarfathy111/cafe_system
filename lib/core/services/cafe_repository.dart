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

part 'cafe_repository_auth.dart';
part 'cafe_repository_backups.dart';
part 'cafe_repository_expenses.dart';
part 'cafe_repository_notes.dart';
part 'cafe_repository_orders.dart';
part 'cafe_repository_products.dart';
part 'cafe_repository_read.dart';
part 'cafe_repository_reports.dart';
part 'cafe_repository_settings.dart';

class CafeRepository {
  CafeRepository({CafeDatabase? database})
    : _database = database ?? CafeDatabase.instance;

  final CafeDatabase _database;
}