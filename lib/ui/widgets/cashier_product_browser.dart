import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/cafe_product.dart';
import 'cashier_components.dart';

class CashierProductBrowser extends StatelessWidget {
  const CashierProductBrowser({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.category,
    required this.onCategoryChanged,
    required this.products,
    required this.hasSelectedPlace,
    required this.activePlaceCount,
    required this.totalPlaceCount,
    required this.onChooseProduct,
    this.placeSelector,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final String category;
  final ValueChanged<String> onCategoryChanged;
  final List<CafeProduct> products;
  final bool hasSelectedPlace;
  final int activePlaceCount;
  final int totalPlaceCount;
  final ValueChanged<CafeProduct> onChooseProduct;
  final Widget? placeSelector;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(22, 17, 22, 10),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'المبيعات',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  Text(
                    'اختار ترابيزة أو أوضة بلايستيشن وابدأ الطلب',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            CafeMetric(
              label: 'أماكن مشغولة',
              value: '$activePlaceCount / $totalPlaceCount',
              icon: Icons.table_restaurant,
            ),
          ],
        ),
      ),
      ?placeSelector,
      Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 9),
        child: TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            hintText: 'ابحث عن مشروب أو صنف...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
      SizedBox(
        height: 43,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          itemCount: AppCategories.values.length,
          separatorBuilder: (_, _) => const SizedBox(width: 7),
          itemBuilder: (context, index) {
            final value = AppCategories.values[index];
            final selected = value == category;
            return ChoiceChip(
              label: Text(value),
              selected: selected,
              showCheckmark: false,
              selectedColor: AppColors.green,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppColors.ink,
              ),
              onSelected: (_) => onCategoryChanged(value),
            );
          },
        ),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: !hasSelectedPlace
            ? const Center(
                child: Text('اختار ترابيزة أو أوضة بلايستيشن لبدء الطلب'),
              )
            : GridView.builder(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 185,
                  mainAxisExtent: 140,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) => CafeProductTile(
                  product: products[index],
                  onTap: () => onChooseProduct(products[index]),
                ),
              ),
      ),
    ],
  );
}
