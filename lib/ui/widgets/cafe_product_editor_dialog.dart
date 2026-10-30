import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/cafe_product.dart';

Future<CafeProduct?> showCafeProductEditor(
  BuildContext context, {
  CafeProduct? product,
}) => showDialog<CafeProduct>(
  context: context,
  builder: (_) => CafeProductEditorDialog(product: product),
);

class CafeProductEditorDialog extends StatefulWidget {
  const CafeProductEditorDialog({super.key, this.product});
  final CafeProduct? product;

  @override
  State<CafeProductEditorDialog> createState() =>
      _CafeProductEditorDialogState();
}

class _CafeProductEditorDialogState extends State<CafeProductEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late String _category;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController = TextEditingController(text: product?.name ?? '');
    _priceController = TextEditingController(
      text: product?.price.toStringAsFixed(2) ?? '',
    );
    _category = product?.category ?? AppCategories.values[1];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final previous = widget.product;
    Navigator.pop(
      context,
      CafeProduct(
        _nameController.text.trim(),
        _category,
        double.parse(_priceController.text.trim()),
        previous?.icon ?? Icons.local_cafe,
        stockUnits: previous?.stockUnits,
        unitsPerCarton: previous?.unitsPerCarton,
        purchasePricePerCarton: previous?.purchasePricePerCarton,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.product == null ? 'إضافة صنف' : 'تعديل الصنف'),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                enabled: widget.product == null,
                decoration: const InputDecoration(labelText: 'اسم الصنف'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'اكتب اسم الصنف'
                    : null,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'القسم'),
                items: AppCategories.values
                    .skip(1)
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'السعر بالجنيه'),
                validator: (value) {
                  final price = double.tryParse(value?.trim() ?? '');
                  return price == null || !price.isFinite || price <= 0
                      ? 'اكتب سعرًا صحيحًا'
                      : null;
                },
              ),
              const SizedBox(height: 10),
              if (widget.product != null)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'اسم الصنف ثابت للحفاظ على ارتباط الفواتير والوصفات القديمة.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      FilledButton(onPressed: _save, child: const Text('حفظ')),
    ],
  );
}
