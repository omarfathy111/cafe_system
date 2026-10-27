import 'cafe_daily_closing.dart';
import 'cafe_order.dart';
import 'cafe_product.dart';
import 'cafe_sale.dart';

class CafeSnapshot {
  const CafeSnapshot({
    required this.orders,
    required this.sales,
    required this.products,
    required this.tableCount,
    this.roomHourlyRates = const {},
    this.dailyClosings = const [],
  });

  final List<CafeOrder> orders;
  final List<CafeSale> sales;
  final List<CafeProduct> products;
  final int tableCount;
  final Map<String, double> roomHourlyRates;
  final List<CafeDailyClosing> dailyClosings;
}
