import 'package:cafe_system/models/cafe_order.dart';
import 'package:flutter/material.dart';

Future<double?> showCafeDiscountDialog(
  BuildContext context,
  CafeOrderItem item,
) => showDialog<double>(
  context: context,
  builder: (_) => CafeDiscountDialog(item: item),
);

class CafeDiscountDialog extends StatefulWidget {
  const CafeDiscountDialog({super.key, required this.item});

  final CafeOrderItem item;

  @override
  State<CafeDiscountDialog> createState() => _CafeDiscountDialogState();
}

class _CafeDiscountDialogState extends State<CafeDiscountDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.item.discountPerUnit == 0
          ? ''
          : widget.item.discountPerUnit.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final discount = double.tryParse(_controller.text.trim()) ?? 0;
    if (!discount.isFinite ||
        discount < 0 ||
        discount > widget.item.unitPrice) {
      setState(() => _error = 'الخصم لازم يكون بين صفر وسعر الوحدة');
      return;
    }
    Navigator.pop(context, discount);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('خصم على الصنف'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${widget.item.productName} • سعر الوحدة ${widget.item.unitPrice.toStringAsFixed(2)} ج.م',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'قيمة الخصم على الوحدة بالجنيه',
            errorText: _error,
            suffixText: 'ج.م',
          ),
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: 6),
        const Text('اكتب 0 لإلغاء الخصم.'),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      FilledButton(onPressed: _save, child: const Text('تطبيق الخصم')),
    ],
  );
}
