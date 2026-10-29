import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/cafe_product.dart';
import 'cafe_page_heading.dart';
import 'cafe_product_editor_dialog.dart';
import 'cafe_room_rates_section.dart';

class CafeMenuPage extends StatelessWidget {
  const CafeMenuPage({
    super.key,
    required this.products,
    required this.onSaveProduct,
    required this.onDeactivateProduct,
    required this.roomHourlyRates,
    required this.onSaveRoomHourlyRate,
  });

  final List<CafeProduct> products;
  final Future<void> Function(CafeProduct product) onSaveProduct;
  final Future<void> Function(CafeProduct product) onDeactivateProduct;
  final Map<String, double> roomHourlyRates;
  final Future<void> Function(int room, String mode, double rate)
  onSaveRoomHourlyRate;

  Future<void> _addProduct(BuildContext context) async {
    final product = await showCafeProductEditor(context);
    if (product != null) await onSaveProduct(product);
  }

  Future<void> _editProduct(BuildContext context, CafeProduct product) async {
    final updated = await showCafeProductEditor(context, product: product);
    if (updated != null) await onSaveProduct(updated);
  }

  Future<void> _confirmDeactivate(
    BuildContext context,
    CafeProduct product,
  ) async {
    final shouldDeactivate = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إخفاء الصنف'),
        content: Text('هل تريد إخفاء ${product.name} من المنيو؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إخفاء'),
          ),
        ],
      ),
    );
    if (shouldDeactivate == true) await onDeactivateProduct(product);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CafePageHeading(
          title: 'إدارة المنيو والأسعار',
          actions: [
            FilledButton.icon(
              onPressed: () => _addProduct(context),
              icon: const Icon(Icons.add),
              label: const Text('إضافة صنف'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: [
              CafeRoomRatesSection(
                rates: roomHourlyRates,
                onSave: onSaveRoomHourlyRate,
              ),
              if (products.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text('لا توجد أصناف في المنيو')),
                ),
              for (final category in AppCategories.values.skip(1))
                if (products.any(
                  (product) => product.category == category,
                )) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      category,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.green,
                      ),
                    ),
                  ),
                  for (final product in products.where(
                    (product) => product.category == category,
                  ))
                    Card(
                      color: Colors.white,
                      child: ListTile(
                        leading: Icon(product.icon, color: AppColors.green),
                        title: Text(product.name),
                        subtitle: Text(
                          '${product.price.toStringAsFixed(2)} ج.م',
                        ),
                        trailing: Wrap(
                          children: [
                            IconButton(
                              tooltip: 'تعديل السعر والقسم',
                              onPressed: () => _editProduct(context, product),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'إخفاء من المنيو',
                              onPressed: () =>
                                  _confirmDeactivate(context, product),
                              icon: const Icon(
                                Icons.visibility_off_outlined,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
            ],
          ),
        ),
      ],
    ),
  );
}
