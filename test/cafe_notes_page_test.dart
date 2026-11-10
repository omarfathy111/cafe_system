import 'package:cafe_system/models/cafe_note.dart';
import 'package:cafe_system/ui/screens/settings/cafe_notes_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('saves a note and displays it in a dated card', (tester) async {
    final notes = <CafeNote>[];
    late StateSetter updateParent;
    final createdAt = DateTime(2026, 11, 8, 9, 30);

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            updateParent = setState;
            return Scaffold(
              body: CafeNotesPage(
                notes: notes,
                onAdd: (text) async {
                  final note = CafeNote(
                    id: 1,
                    text: text,
                    createdAt: createdAt,
                  );
                  updateParent(() => notes.insert(0, note));
                  return note;
                },
              ),
            );
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'راجع طلب المورد');
    await tester.tap(find.text('حفظ الملاحظة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('راجع طلب المورد'), findsOneWidget);
    expect(find.text('08/11/2026 • 09:30'), findsOneWidget);
    expect(find.text('1 ملاحظة'), findsOneWidget);
    expect(find.byType(Card), findsNWidgets(2));
    expect(find.byType(TextField), findsOneWidget);
  });
}
