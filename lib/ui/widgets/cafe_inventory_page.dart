import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/cafe_product.dart';

class CafeInventoryPage extends StatefulWidget {
  const CafeInventoryPage({
    super.key,
    required this.products,
    required this.onAddStockProduct,
    required this.onRestock,
    required this.onLoadSales,
  });

  final List<CafeProduct> products;
  final Future<void> Function(CafeProduct product) onAddStockProduct;
  final Future<void> Function(
    CafeProduct product,
    int cartons,
    double purchasePrice,
  )
  onRestock;
  final Future<Map<String, int>> Function(DateTime from, DateTime through)
  onLoadSales;

  @override
  State<CafeInventoryPage> createState() => _CafeInventoryPageState();
}

class _CafeInventoryPageState extends State<CafeInventoryPage> {
  static const _allProducts = '__all_products__';
  DateTime _from = DateTime.now().subtract(const Duration(days: 6));
  DateTime _through = DateTime.now();
  String _selectedProduct = _allProducts;
  Map<String, int> _sold = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final result = await widget.onLoadSales(_from, _through);
      if (mounted) {
        setState(() {
          _sold = _selectedProduct == _allProducts
              ? result
              : {
                  if (result.containsKey(_selectedProduct))
                    _selectedProduct: result[_selectedProduct]!,
                };
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate(bool start) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: start ? _from : _through,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (selected == null) return;
    setState(() {
      if (start) {
        _from = selected;
      } else {
        _through = selected;
      }
    });
    await _refresh();
  }

  Future<void> _addProduct() async {
    final result = await showDialog<CafeProduct>(
      context: context,
      builder: (context) => const _StockProductDialog(),
    );
    if (result != null) await widget.onAddStockProduct(result);
  }

  Future<void> _restock(CafeProduct product) async {
    final controller = TextEditingController(text: '1');
    final priceController = TextEditingController(
      text: product.purchasePricePerCarton?.toStringAsFixed(2) ?? '',
    );
    final result = await showDialog<(int, double)>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('إضافة ${product.name} للمخزون'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'عدد الكراتين'),
            ),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'سعر شراء الكرتونة'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final cartons = int.tryParse(controller.text.trim());
              final price = double.tryParse(priceController.text.trim());
              if (cartons != null &&
                  cartons > 0 &&
                  price != null &&
                  price > 0) {
                Navigator.pop(context, (cartons, price));
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    controller.dispose();
    priceController.dispose();
    if (result != null) {
      await widget.onRestock(product, result.$1, result.$2);
    }
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  String _stockLabel(CafeProduct product) {
    final units = product.stockUnits ?? 0;
    final packSize = product.unitsPerCarton ?? 1;
    final cartons = units ~/ packSize;
    final looseUnits = units % packSize;
    return '$cartons كرتونة و$looseUnits قطعة متاحة';
  }

  @override
  Widget build(BuildContext context) {
    final stocked = widget.products.where((product) => product.tracksStock);
    final soldProducts = _sold.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'الجرد والمخزون',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: _addProduct,
                icon: const Icon(Icons.add),
                label: const Text('صنف بالكرتونة'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('الأصناف المباعة من'),
                  SizedBox(
                    width: 210,
                    child: DropdownButtonFormField<String>(
                      value: _selectedProduct,
                      decoration: const InputDecoration(
                        labelText: 'الصنف',
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: _allProducts,
                          child: Text('كل الأصناف'),
                        ),
                        for (final product in widget.products)
                          DropdownMenuItem<String>(
                            value: product.name,
                            child: Text(
                              product.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) async {
                        if (value == null) return;
                        setState(() => _selectedProduct = value);
                        await _refresh();
                      },
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pickDate(true),
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(_date(_from)),
                  ),
                  const Text('إلى'),
                  OutlinedButton.icon(
                    onPressed: () => _pickDate(false),
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(_date(_through)),
                  ),
                  if (_loading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    'الكميات المباعة',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (soldProducts.isEmpty)
                  const Card(
                    color: Colors.white,
                    child: ListTile(title: Text('لا توجد مبيعات في المدة دي')),
                  ),
                for (final entry in soldProducts)
                  Card(
                    color: Colors.white,
                    child: ListTile(
                      leading: const Icon(
                        Icons.local_cafe_outlined,
                        color: AppColors.green,
                      ),
                      title: Text(entry.key),
                      trailing: Text(
                        '${entry.value} وحدة',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    'مخزون الكراتين',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (stocked.isEmpty)
                  const Card(
                    color: Colors.white,
                    child: ListTile(title: Text('أضف أول صنف مخزني بالكرتونة')),
                  ),
                for (final product in stocked)
                  Card(
                    color: Colors.white,
                    child: ListTile(
                      leading: const Icon(
                        Icons.inventory_2_outlined,
                        color: AppColors.green,
                      ),
                      title: Text(product.name),
                      subtitle: Text(
                        '${_stockLabel(product)} • ${product.unitsPerCarton} قطعة/كرتونة • شراء آخر كرتونة ${product.purchasePricePerCarton?.toStringAsFixed(2) ?? '—'} ج.م',
                      ),
                      trailing: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('${product.price.toStringAsFixed(2)} ج.م'),
                          IconButton(
                            tooltip: 'إضافة كراتين',
                            onPressed: () => _restock(product),
                            icon: const Icon(Icons.add_box_outlined),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StockProductDialog extends StatefulWidget {
  const _StockProductDialog();

  @override
  State<_StockProductDialog> createState() => _StockProductDialogState();
}

class _StockProductDialogState extends State<_StockProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _cartons = TextEditingController(text: '1');
  final _unitsPerCarton = TextEditingController();
  final _purchasePrice = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _cartons.dispose();
    _unitsPerCarton.dispose();
    _purchasePrice.dispose();
    super.dispose();
  }

  String? _positiveInt(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    return number == null || number <= 0 ? 'أدخل رقمًا صحيحًا' : null;
  }

  String? _positivePrice(String? value) {
    final number = double.tryParse(value?.trim() ?? '');
    return number == null || number <= 0 ? 'أدخل سعرًا صحيحًا' : null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      CafeProduct(
        _name.text.trim(),
        'أكلات',
        double.parse(_price.text.trim()),
        Icons.fastfood_outlined,
        stockUnits:
            int.parse(_cartons.text.trim()) *
            int.parse(_unitsPerCarton.text.trim()),
        unitsPerCarton: int.parse(_unitsPerCarton.text.trim()),
        purchasePricePerCarton: double.parse(_purchasePrice.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('إضافة صنف بالكرتونة'),
    content: SizedBox(
      width: 410,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'اسم الصنف'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'اكتب الاسم' : null,
              ),
              TextFormField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'سعر بيع القطعة'),
                validator: _positivePrice,
              ),
              TextFormField(
                controller: _cartons,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'عدد الكراتين المشتراة',
                ),
                validator: _positiveInt,
              ),
              TextFormField(
                controller: _unitsPerCarton,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'عدد القطع في الكرتونة',
                ),
                validator: _positiveInt,
              ),
              TextFormField(
                controller: _purchasePrice,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'سعر شراء الكرتونة',
                ),
                validator: _positivePrice,
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
      FilledButton(
        onPressed: _save,
        child: const Text('إضافة للمنيو والمخزون'),
      ),
    ],
  );
}
