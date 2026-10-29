import 'package:flutter/material.dart';

import '../../data/models/cafe_order.dart';

import 'cafe_page_heading.dart';
import 'cafe_place_widgets.dart';

class CafeTablesPage extends StatelessWidget {
  const CafeTablesPage({
    super.key,
    required this.tableCount,
    required this.orders,
    required this.onSelect,
    required this.onSelectTakeaway,
  });

  final int tableCount;
  final List<CafeOrder> orders;
  final void Function(bool isRoom, int number) onSelect;
  final VoidCallback onSelectTakeaway;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CafePageHeading(title: 'أماكن الجلوس'),
        const SizedBox(height: 14),
        Expanded(
          child: CafePlaceGrid(
            tableCount: tableCount,
            orders: orders,
            onSelect: onSelect,
            onSelectTakeaway: onSelectTakeaway,
          ),
        ),
      ],
    ),
  );
}
