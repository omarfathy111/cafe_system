import 'package:cafe_system/core/utils/app_constants.dart';
import 'package:cafe_system/models/cafe_order.dart';
import 'package:cafe_system/models/default_cafe_products.dart';
import 'package:flutter/material.dart';

class CafeOrderContents extends StatelessWidget {
  const CafeOrderContents({
    super.key,
    required this.order,
    required this.onChange,
    required this.onDiscount,
    this.onAddShishaStone,
  });
  final CafeOrder order;
  final void Function(CafeOrderItem item, int delta) onChange;
  final ValueChanged<CafeOrderItem> onDiscount;
  final VoidCallback? onAddShishaStone;
  @override
  Widget build(BuildContext context) {
    if (order.items.isEmpty) {
      return const Center(
        child: Text('الطلب فارغ', style: TextStyle(color: Colors.black45)),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      children: order.items.map((item) {
        final product = cafeProducts
            .where((p) => p.name == item.productName)
            .firstOrNull;
        final price = item.unitPrice > 0 ? item.unitPrice : product?.price ?? 0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 7,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${price.toStringAsFixed(2)} ج.م للواحد',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.ink,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (item.discountPerUnit > 0)
                          Text(
                            'خصم ${item.discountPerUnit.toStringAsFixed(2)} ج.م',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        Text(
                          '${item.discountPerUnit > 0 ? 'الصافي' : 'الإجمالي'} ${item.total.toStringAsFixed(2)} ج.م',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.green,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    if (item.productName == 'شيشة' && onAddShishaStone != null)
                      TextButton.icon(
                        onPressed: onAddShishaStone,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('إضافة حجر'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'خصم على الصنف',
                visualDensity: VisualDensity.compact,
                onPressed: () => onDiscount(item),
                icon: const Icon(Icons.sell_outlined, color: AppColors.orange),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => onChange(item, -1),
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: Colors.black45,
                ),
              ),
              Text(
                '${item.quantity}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => onChange(item, 1),
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: AppColors.green,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
