import 'package:cafe_system/core/utils/app_constants.dart';
import 'package:cafe_system/models/cafe_product.dart';
import 'package:flutter/material.dart';

class CafeProductTile extends StatelessWidget {
  const CafeProductTile({
    super.key,
    required this.product,
    required this.onTap,
  });
  final CafeProduct product;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(15),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2ED),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(product.icon, color: AppColors.green),
            ),
            const Spacer(),
            Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.ink,
              ),
            ),
            if (product.tracksStock)
              Text(
                'متاح: ${product.stockUnits}',
                style: TextStyle(
                  fontSize: 11,
                  color: (product.stockUnits ?? 0) > 0
                      ? AppColors.green
                      : Colors.redAccent,
                ),
              ),
            const SizedBox(height: 3),
            Row(
              children: [
                Text(
                  '${product.price.toStringAsFixed(0)} ج.م',
                  style: const TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.add_circle, color: AppColors.green, size: 20),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
