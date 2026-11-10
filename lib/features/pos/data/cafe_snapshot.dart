import 'package:cafe_system/features/orders_history/data/cafe_sale.dart';
import 'package:cafe_system/features/pos/data/cafe_order.dart';
import 'package:cafe_system/features/products/data/cafe_product.dart';
import 'package:cafe_system/features/reports/data/cafe_daily_closing.dart';
import 'package:cafe_system/features/reports/data/cafe_expense.dart';
import 'package:cafe_system/features/settings/data/cafe_note.dart';

class CafeSnapshot {
  const CafeSnapshot({
    required this.orders,
    required this.sales,
    required this.products,
    this.inventoryProducts = const [],
    required this.tableCount,
    this.roomHourlyRates = const {},
    this.dailyClosings = const [],
    this.expenses = const [],
    this.placeNames = const {},
    this.notes = const [],
    this.categories = const [],
  });

  final List<CafeOrder> orders;
  final List<CafeSale> sales;
  final List<CafeProduct> products;
  final List<CafeProduct> inventoryProducts;
  final int tableCount;
  final Map<String, double> roomHourlyRates;
  final List<CafeDailyClosing> dailyClosings;
  final List<CafeExpense> expenses;
  final Map<String, String> placeNames;
  final List<CafeNote> notes;
  final List<String> categories;
}
