import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/cafe_inventory_total.dart';
import '../../data/models/cafe_product.dart';
import 'cafe_page_heading.dart';

class CafeInventoryPage extends StatefulWidget {
  const CafeInventoryPage({
    super.key,
    required this.products,
    required this.onAddStockProduct,
    required this.onRestock,
    this.onEditStockProduct,
    required this.onLoadSales,
  });

  final List<CafeProduct> products;
  final Future<void> Function(CafeProduct product) onAddStockProduct;
  final Future<void> Function(CafeProduct original, CafeProduct updated)?
  onEditStockProduct;
  final Future<void> Function(
    CafeProduct product,
    int cartons,
    double purchasePrice,
  )
  onRestock;
  final Future<Map<String, CafeInventoryTotal>> Function(
    DateTime from,
    DateTime through,
  )
  onLoadSales;

  @override
  State<CafeInventoryPage> createState() => _CafeInventoryPageState();
}

class _CafeInventoryPageState extends State<CafeInventoryPage> {
  DateTime _from = DateTime.now().subtract(const Duration(days: 6));
  DateTime _through = DateTime.now();
  Set<String> _selectedProducts = {};
  Map<String, CafeInventoryTotal> _sold = {};
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
          _sold = _selectedProducts.isEmpty
              ? result
              : Map.fromEntries(
                  result.entries.where(
                    (entry) => _selectedProducts.contains(entry.key),
                  ),
                );
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

  Future<void> _pickProducts() async {
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) {
        final selected = Set<String>.of(_selectedProducts);
        return StatefulBuilder(
          builder: (context, updateDialog) => AlertDialog(
            title: const Text('اختيار أصناف الجرد'),
            content: SizedBox(
              width: 380,
              height: 380,
              child: ListView(
                children: [
                  for (final product in widget.products)
                    CheckboxListTile(
                      dense: true,
                      value: selected.contains(product.name),
                      title: Text(product.name),
                      onChanged: (checked) => updateDialog(() {
                        if (checked == true) {
                          selected.add(product.name);
                        } else {
                          selected.remove(product.name);
                        }
                      }),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, <String>{}),
                child: const Text('كل الأصناف'),
              ),
              FilledButton(
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.pop(dialogContext, selected),
                child: const Text('تطبيق الاختيار'),
              ),
            ],
          ),
        );
      },
    );
    if (result == null) return;
    setState(() {
      _selectedProducts = result;
    });
    await _refresh();
  }

  Future<void> _showAllProducts() async {
    setState(() => _selectedProducts = {});
    await _refresh();
  }

  Future<void> _addProduct() async {
    final result = await showDialog<CafeProduct>(
      context: context,
      builder: (context) => const _StockProductDialog(),
    );
    if (result != null) await widget.onAddStockProduct(result);
  }

  Future<void> _editProduct(CafeProduct product) async {
    final updated = await showDialog<CafeProduct>(
      context: context,
      builder: (_) => _StockProductDialog(product: product),
    );
    if (updated != null)
      await widget.onEditStockProduct?.call(product, updated);
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
                  price.isFinite &&
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

  String? _soldCartonLabel(String productName, int quantity) {
    final packSize = _sold[productName]?.unitsPerCarton;
    if (packSize == null || packSize <= 0) return null;
    return '${quantity ~/ packSize} كرتونة و${quantity % packSize} قطعة';
  }

  Widget _sectionTitle(String title, IconData icon, int count) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
    child: Row(
      children: [
        Icon(icon, color: AppColors.green, size: 21),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(width: 8),
        CircleAvatar(
          radius: 12,
          backgroundColor: const Color(0xFFEAF2ED),
          child: Text(
            '$count',
            style: const TextStyle(fontSize: 11, color: AppColors.green),
          ),
        ),
      ],
    ),
  );

  Widget _saleCard(MapEntry<String, CafeInventoryTotal> entry) {
    final cartonLabel = _soldCartonLabel(entry.key, entry.value.quantity);
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE9ECE7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2ED),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.local_cafe_outlined,
                    color: AppColors.green,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    entry.key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF2ED),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${entry.value.quantity} ',
                                style: const TextStyle(
                                  color: AppColors.green,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const TextSpan(
                                text: 'وحدة مباعة',
                                style: TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (cartonLabel != null)
                        Text(
                          cartonLabel,
                          style: const TextStyle(
                            color: AppColors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '${entry.value.amount.toStringAsFixed(2)} ج.م',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stockCard(CafeProduct product) => Card(
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: Color(0xFFE9ECE7)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2ED),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: AppColors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
              ),
              if (widget.onEditStockProduct != null)
                IconButton(
                  tooltip: 'تعديل بيانات الصنف',
                  onPressed: () => _editProduct(product),
                  icon: const Icon(Icons.tune_outlined),
                  color: AppColors.green,
                ),
              IconButton(
                tooltip: 'إضافة كراتين',
                onPressed: () => _restock(product),
                icon: const Icon(Icons.add_box_outlined),
                color: AppColors.green,
              ),
            ],
          ),
          const Spacer(),
          Text(
            _stockLabel(product),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.green,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${product.unitsPerCarton} قطعة بالكرتونة • الشراء ${product.purchasePricePerCarton?.toStringAsFixed(2) ?? '—'} ج.م/كرتونة • البيع ${product.price.toStringAsFixed(2)} ج.م/قطعة',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.ink,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );

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
          CafePageHeading(
            title: 'الجرد والمخزون',
            subtitle: 'تابع المبيعات والكميات المتاحة',
            icon: Icons.inventory_2_outlined,
            actions: [
              FilledButton.icon(
                onPressed: _addProduct,
                icon: const Icon(Icons.add),
                label: const Text('صنف بالكرتونة'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFE9ECE7)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.filter_alt_outlined,
                        color: AppColors.green,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'تصفية المبيعات',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      if (_loading)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ChoiceChip(
                        selected: _selectedProducts.isEmpty,
                        avatar: const Icon(Icons.apps, size: 18),
                        label: const Text('كل الأصناف'),
                        onSelected: (_) => _showAllProducts(),
                      ),
                      ChoiceChip(
                        selected: _selectedProducts.isNotEmpty,
                        avatar: const Icon(Icons.checklist, size: 18),
                        label: Text(
                          _selectedProducts.isEmpty
                              ? 'اختيار أصناف'
                              : '${_selectedProducts.length} أصناف مختارة',
                        ),
                        onSelected: (_) => _pickProducts(),
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
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                _sectionTitle(
                  'ملخص المبيعات',
                  Icons.point_of_sale_outlined,
                  soldProducts.length,
                ),
                if (soldProducts.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'لا توجد مبيعات في الأصناف أو المدة المحددة',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                if (soldProducts.isNotEmpty)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: soldProducts.length,
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 310,
                          mainAxisExtent: 128,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemBuilder: (context, index) =>
                        _saleCard(soldProducts[index]),
                  ),
                _sectionTitle(
                  'رصيد المخزون',
                  Icons.inventory_2_outlined,
                  stocked.length,
                ),
                if (stocked.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'أضف صنفًا بالكرتونة ليظهر رصيده هنا',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                if (stocked.isNotEmpty)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: stocked.length,
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 340,
                          mainAxisExtent: 145,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemBuilder: (context, index) =>
                        _stockCard(stocked.elementAt(index)),
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
  const _StockProductDialog({this.product});

  final CafeProduct? product;

  @override
  State<_StockProductDialog> createState() => _StockProductDialogState();
}

class _StockProductDialogState extends State<_StockProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _cartons = TextEditingController(text: '1');
  final _looseUnits = TextEditingController(text: '0');
  final _unitsPerCarton = TextEditingController();
  final _purchasePrice = TextEditingController();
  String _category = 'سناكس';

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    if (product == null) return;
    final packSize = product.unitsPerCarton ?? 1;
    final stock = product.stockUnits ?? 0;
    _name.text = product.name;
    _category = product.category;
    _price.text = product.price.toString();
    _cartons.text = (stock ~/ packSize).toString();
    _looseUnits.text = (stock % packSize).toString();
    _unitsPerCarton.text = packSize.toString();
    _purchasePrice.text = product.purchasePricePerCarton?.toString() ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _cartons.dispose();
    _looseUnits.dispose();
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
    return number == null || !number.isFinite || number <= 0
        ? 'أدخل سعرًا صحيحًا'
        : null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final unitsPerCarton = int.parse(_unitsPerCarton.text.trim());
    Navigator.pop(
      context,
      CafeProduct(
        _name.text.trim(),
        _category,
        double.parse(_price.text.trim()),
        widget.product?.icon ?? Icons.fastfood_outlined,
        stockUnits:
            int.parse(_cartons.text.trim()) * unitsPerCarton +
            int.parse(_looseUnits.text.trim()),
        unitsPerCarton: unitsPerCarton,
        purchasePricePerCarton: double.parse(_purchasePrice.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.product == null ? 'إضافة صنف بالكرتونة' : 'تعديل بيانات الصنف',
    ),
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
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'قسم المنيو'),
                items: AppCategories.values
                    .where((category) => category != AppCategories.all)
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
                  labelText: 'عدد الكراتين في المخزون',
                ),
                validator: (value) {
                  final number = int.tryParse(value?.trim() ?? '');
                  return number == null || number < 0
                      ? 'أدخل عددًا صحيحًا'
                      : null;
                },
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
                controller: _looseUnits,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'قطع خارج الكراتين',
                ),
                validator: (value) {
                  final number = int.tryParse(value?.trim() ?? '');
                  final packSize = int.tryParse(_unitsPerCarton.text.trim());
                  return number == null ||
                          number < 0 ||
                          (packSize != null && number >= packSize)
                      ? 'أدخل قطعًا أقل من حجم الكرتونة'
                      : null;
                },
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
        child: Text(
          widget.product == null ? 'إضافة للمنيو والمخزون' : 'حفظ التعديلات',
        ),
      ),
    ],
  );
}
