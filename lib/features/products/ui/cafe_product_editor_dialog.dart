import 'package:cafe_system/core/utils/app_constants.dart';
import 'package:cafe_system/features/products/data/cafe_product.dart';
import 'package:flutter/material.dart';

Future<CafeProduct?> showCafeProductEditor(
  BuildContext context, {
  CafeProduct? product,
  List<String> categories = AppCategories.values,
}) => showDialog<CafeProduct>(
  context: context,
  builder: (_) =>
      CafeProductEditorDialog(product: product, categories: categories),
);

class CafeProductEditorDialog extends StatefulWidget {
  const CafeProductEditorDialog({
    super.key,
    this.product,
    this.categories = AppCategories.values,
  });
  final CafeProduct? product;
  final List<String> categories;

  @override
  State<CafeProductEditorDialog> createState() =>
      _CafeProductEditorDialogState();
}

class _CafeProductEditorDialogState extends State<CafeProductEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _unitsPerCartonController;
  late String _category;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController = TextEditingController(text: product?.name ?? '');
    _priceController = TextEditingController(
      text: product?.price.toStringAsFixed(2) ?? '',
    );
    _unitsPerCartonController = TextEditingController(
      text: product?.unitsPerCarton?.toString() ?? '',
    );
    _category = product?.category ?? widget.categories.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _unitsPerCartonController.dispose();
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
        unitsPerCarton: previous?.tracksStock == true
            ? int.tryParse(_unitsPerCartonController.text.trim())
            : previous?.unitsPerCarton,
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
                decoration: const InputDecoration(labelText: 'اسم الصنف'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'اكتب اسم الصنف'
                    : null,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'القسم'),
                items: widget.categories
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
              if (widget.product?.tracksStock == true)
                TextFormField(
                  controller: _unitsPerCartonController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'عدد القطع في الكرتونة',
                  ),
                  validator: (value) {
                    final units = int.tryParse(value?.trim() ?? '');
                    return units == null || units <= 0
                        ? 'أدخل عدد قطع صحيح أكبر من صفر'
                        : null;
                  },
                ),
              if (widget.product?.tracksStock == true)
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
                    'تغيير الاسم سيحدّث ظهوره في الطلبات والفواتير السابقة أيضًا.',
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
