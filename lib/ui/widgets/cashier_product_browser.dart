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
    required this.categories,
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
  final List<String> categories;
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
      _CashierCategorySelector(
        categories: [
          ...AppCategories.values,
          ...categories.where((item) => !AppCategories.values.contains(item)),
        ],
        selectedCategory: category,
        onSelected: onCategoryChanged,
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

class _CashierCategorySelector extends StatefulWidget {
  const _CashierCategorySelector({
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
  });

  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onSelected;

  @override
  State<_CashierCategorySelector> createState() =>
      _CashierCategorySelectorState();
}

class _CashierCategorySelectorState extends State<_CashierCategorySelector> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scroll(double distance) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final target = (_scrollController.offset + distance)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    child: Row(
      children: [
        IconButton(
          tooltip: 'تحريك الأقسام لليمين',
          onPressed: () => _scroll(-260),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: ListView.separated(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: widget.categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 7),
              itemBuilder: (context, index) {
                final value = widget.categories[index];
                final selected = value == widget.selectedCategory;
                return ChoiceChip(
                  label: Text(value),
                  selected: selected,
                  showCheckmark: false,
                  selectedColor: AppColors.green,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppColors.ink,
                  ),
                  onSelected: (_) => widget.onSelected(value),
                );
              },
            ),
          ),
        ),
        IconButton(
          tooltip: 'تحريك الأقسام لليسار',
          onPressed: () => _scroll(260),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    ),
  );
}
