import 'package:cafe_system/features/pos/ui/cashier_screen.dart';
import 'package:cafe_system/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opens the cafe cashier', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.byType(CashierScreen), findsOneWidget);
  });
}
