import 'package:cafe_system/core/widgets/cafe_page_heading.dart';
import 'package:cafe_system/features/pos/data/cafe_order.dart';
import 'package:cafe_system/features/pos/ui/widgets/cafe_place_widgets.dart';
import 'package:flutter/material.dart';

class CafeTablesPage extends StatelessWidget {
  const CafeTablesPage({
    super.key,
    required this.tableCount,
    required this.orders,
    required this.onSelect,
    required this.onSelectTakeaway,
    this.placeNames = const {},
    this.placeNotes = const {},
    this.onSaveTableName,
    this.onEditPlaceNote,
  });

  final int tableCount;
  final List<CafeOrder> orders;
  final void Function(bool isRoom, int number) onSelect;
  final VoidCallback onSelectTakeaway;
  final Map<String, String> placeNames;
  final Map<String, String> placeNotes;
  final Future<void> Function(int number, String name)? onSaveTableName;
  final void Function(bool isRoom, int number, bool isTakeaway)?
  onEditPlaceNote;

  Future<void> _editTableName(BuildContext context, int number) async {
    final controller = TextEditingController(
      text: placeNames['table_$number'] ?? '',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('تعديل اسم الترابيزة $number'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'الاسم الجديد'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null) await onSaveTableName?.call(number, name);
  }

  Future<void> _chooseTableName(BuildContext context) async {
    final number = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('اختار ترابيزة لتعديل اسمها'),
        children: [
          for (var table = 1; table <= tableCount; table++)
            ListTile(
              title: Text(placeNames['table_$table'] ?? 'ترابيزة $table'),
              onTap: () => Navigator.pop(dialogContext, table),
            ),
        ],
      ),
    );
    if (number != null && context.mounted) {
      await _editTableName(context, number);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CafePageHeading(title: 'أماكن الجلوس'),
        const SizedBox(height: 14),
        if (onSaveTableName != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: () => _chooseTableName(context),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('تعديل أسماء الترابيزات'),
            ),
          ),
        Expanded(
          child: CafePlaceGrid(
            tableCount: tableCount,
            orders: orders,
            onSelect: onSelect,
            onSelectTakeaway: onSelectTakeaway,
            placeNames: placeNames,
            placeNotes: placeNotes,
            onPlaceNoteTap: onEditPlaceNote,
          ),
        ),
      ],
    ),
  );
}
