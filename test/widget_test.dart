import 'package:cafe_system/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opens the cafe cashier', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.text('المبيعات'), findsOneWidget);
    expect(find.text('الكاشير'), findsOneWidget);
  });
}
