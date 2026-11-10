import 'package:cafe_system/core/utils/app_constants.dart';
import 'package:cafe_system/features/orders_history/data/cafe_sale.dart';
import 'package:cafe_system/features/orders_history/data/cafe_sale_item.dart';
import 'package:flutter/material.dart';

Future<(List<CafeSaleItem>, String)?> showCafeInvoiceEditor(
  BuildContext context,
  CafeSale sale,
) => showDialog<(List<CafeSaleItem>, String)>(
  context: context,
  builder: (_) => _CafeInvoiceEditorDialog(sale: sale),
);

class _CafeInvoiceEditorDialog extends StatefulWidget {
  const _CafeInvoiceEditorDialog({required this.sale});

  final CafeSale sale;

  @override
  State<_CafeInvoiceEditorDialog> createState() =>
      _CafeInvoiceEditorDialogState();
}

class _CafeInvoiceEditorDialogState extends State<_CafeInvoiceEditorDialog> {
  late final TextEditingController _noteController;
  late final List<CafeSaleItem> _items;

  double get _total =>
      widget.sale.roomCharge +
      _items.fold<double>(0, (sum, item) => sum + item.total);

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.sale.note);
    _items = widget.sale.saleItems.map((item) => item.copyWith()).toList();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _changeQuantity(int index, int delta) {
    final updatedQuantity = _items[index].quantity + delta;
    setState(() {
      if (updatedQuantity <= 0) {
        _items.removeAt(index);
      } else {
        _items[index] = _items[index].copyWith(quantity: updatedQuantity);
      }
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('تعديل فاتورة ${widget.sale.label}'),
    content: SizedBox(
      width: 520,
      height: 430,
      child: Column(
        children: [
          Expanded(
            child: _items.isEmpty
                ? const Center(
                    child: Text('لا توجد أصناف قابلة للتعديل في الفاتورة'),
                  )
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final netPrice = item.unitPrice - item.discountPerUnit;
                      return Card(
                        color: const Color(0xFFF7F8F5),
                        child: ListTile(
                          title: Text(item.productName),
                          subtitle: Text(
                            '${netPrice.toStringAsFixed(2)} ج.م للقطعة • ${(item.quantity * netPrice).toStringAsFixed(2)} ج.م',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'تقليل الكمية',
                                onPressed: () => _changeQuantity(index, -1),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              SizedBox(
                                width: 30,
                                child: Text(
                                  '${item.quantity}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'زيادة الكمية',
                                onPressed: () => _changeQuantity(index, 1),
                                icon: const Icon(
                                  Icons.add_circle_outline,
                                  color: AppColors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (widget.sale.roomCharge > 0)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'حساب الغرفة: ${widget.sale.roomCharge.toStringAsFixed(2)} ج.م',
                ),
              ),
            ),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(labelText: 'ملاحظة الفاتورة'),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              'الإجمالي بعد التعديل: ${_total.toStringAsFixed(2)} ج.م',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.green,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      FilledButton(
        onPressed: _items.isEmpty && widget.sale.roomCharge <= 0
            ? null
            : () => Navigator.pop(context, (
                _items.toList(),
                _noteController.text.trim(),
              )),
        child: const Text('حفظ التعديلات'),
      ),
    ],
  );
}
