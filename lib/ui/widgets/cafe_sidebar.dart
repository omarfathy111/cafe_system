import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

class CafeSidebar extends StatelessWidget {
  const CafeSidebar({
    super.key,
    required this.selected,
    required this.onSelect,
  });
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 210,
    child: Material(
      color: AppColors.ink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.local_cafe, color: Color(0xFFE8B17D), size: 31),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ' قهوة كوخ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'إدارة الكافيه',
                      style: TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          for (final entry in [
            (0, Icons.point_of_sale, 'الكاشير'),
            (1, Icons.table_restaurant, 'الترابيزات'),
            (2, Icons.bar_chart, 'التقارير'),
            (3, Icons.restaurant_menu, 'المنيو'),
            (4, Icons.inventory_2_outlined, 'جرد'),
            (5, Icons.backup_outlined, 'النسخ الاحتياطي'),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              child: ListTile(
                dense: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                selected: selected == entry.$1,
                selectedTileColor: const Color(0xFF315047),
                leading: Icon(
                  entry.$2,
                  color: selected == entry.$1
                      ? const Color(0xFFE8B17D)
                      : Colors.white70,
                ),
                title: Text(
                  entry.$3,
                  style: TextStyle(
                    color: selected == entry.$1 ? Colors.white : Colors.white70,
                  ),
                ),
                onTap: () => onSelect(entry.$1),
              ),
            ),
          const Spacer(),
        ],
      ),
    ),
  );
}
