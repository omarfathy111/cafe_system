import 'package:cafe_system/core/utils/app_constants.dart';
import 'package:cafe_system/core/widgets/cafe_page_heading.dart';
import 'package:cafe_system/features/products/data/cafe_product.dart';
import 'package:cafe_system/features/products/ui/cafe_product_editor_dialog.dart';
import 'package:cafe_system/features/products/ui/cafe_room_rates_section.dart';
import 'package:flutter/material.dart';

class CafeMenuPage extends StatelessWidget {
  const CafeMenuPage({
    super.key,
    required this.products,
    this.categories = AppCategories.values,
    this.onAddCategory,
    required this.onSaveProduct,
    this.onRenameProduct,
    required this.onDeactivateProduct,
    required this.roomHourlyRates,
    required this.onSaveRoomHourlyRate,
    this.roomNames = const {},
    this.onSaveRoomName,
  });

  final List<CafeProduct> products;
  final List<String> categories;
  final Future<void> Function(String name)? onAddCategory;
  final Future<void> Function(CafeProduct product) onSaveProduct;
  final Future<void> Function(String previousName, CafeProduct product)?
  onRenameProduct;
  final Future<void> Function(CafeProduct product) onDeactivateProduct;
  final Map<String, double> roomHourlyRates;
  final Future<void> Function(int room, String mode, double rate)
  onSaveRoomHourlyRate;
  final Map<String, String> roomNames;
  final Future<void> Function(int number, String name)? onSaveRoomName;

  Future<void> _addProduct(BuildContext context) async {
    final product = await showCafeProductEditor(
      context,
      categories: categories,
    );
    if (product != null) await onSaveProduct(product);
  }

  Future<void> _editProduct(BuildContext context, CafeProduct product) async {
    final updated = await showCafeProductEditor(
      context,
      product: product,
      categories: categories,
    );
    if (updated != null) {
      if (updated.name != product.name && onRenameProduct != null) {
        await onRenameProduct!(product.name, updated);
      } else {
        await onSaveProduct(updated);
      }
    }
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
            if (onAddCategory != null)
              OutlinedButton.icon(
                onPressed: () => _addCategory(context),
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const Text('إضافة قسم'),
              ),
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
                roomNames: roomNames,
                onSaveRoomName: onSaveRoomName,
              ),
              if (products.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text('لا توجد أصناف في المنيو')),
                ),
              for (final category in categories)
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

  Future<void> _addCategory(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إضافة قسم جديد'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'اسم القسم'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.trim().isNotEmpty) {
      await onAddCategory?.call(name.trim());
    }
  }
}
