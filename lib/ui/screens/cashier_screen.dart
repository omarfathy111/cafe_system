import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/cafe_daily_closing.dart';
import '../../data/models/cafe_expense.dart';
import '../../data/models/cafe_note.dart';
import '../../data/models/cafe_order.dart';
import '../../data/models/cafe_product.dart';
import '../../data/models/cafe_sale.dart';
import '../../data/repositories/cafe_repository.dart';
import '../widgets/cashier_components.dart';
import '../widgets/cafe_pages.dart';
import '../widgets/cafe_place_widgets.dart';
import '../widgets/cashier_product_browser.dart';
import '../widgets/cafe_order_panel.dart';
import '../widgets/cafe_order_dialogs.dart';
import '../widgets/cafe_backup_page.dart';
import '../widgets/admin_password_dialog.dart';
import '../widgets/cafe_room_booking_dialog.dart';
import '../widgets/cafe_discount_dialog.dart';
import '../widgets/cafe_inventory_page.dart';
import '../widgets/cafe_notes_page.dart';

class CashierScreen extends StatefulWidget {
  const CashierScreen({super.key});
  static const routeName = 'cashier';
  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen> {
  final _repository = CafeRepository();
  final _searchController = TextEditingController();
  Future<void> _pendingWrites = Future.value();
  final List<CafeOrder> _orders = [];
  final List<CafeSale> _sales = [];
  final List<CafeProduct> _products = [];
  final List<CafeDailyClosing> _dailyClosings = [];
  final List<CafeExpense> _expenses = [];
  final List<CafeNote> _notes = [];
  final Map<String, double> _roomHourlyRates = {};
  final Map<String, String> _placeNames = {};
  int _tableCount = 16;
  int _selectedNav = 0;
  int? _selectedTable;
  int? _selectedRoom;
  bool _selectedTakeaway = false;
  String _category = AppCategories.all;
  String _search = '';
  bool _loading = true;
  bool _adminUnlocked = false;
  Timer? _roomTicker;

  CafeOrder? get _activeOrder => _orders.where((order) {
    if (_selectedTakeaway) return order.isTakeaway;
    if (_selectedRoom != null) return order.roomNumber == _selectedRoom;
    return _selectedTable != null && order.tableNumber == _selectedTable;
  }).firstOrNull;
  List<CafeProduct> get _visibleProducts => _products
      .where(
        (product) =>
            (_category == AppCategories.all || product.category == _category) &&
            (_search.isEmpty || product.name.contains(_search)),
      )
      .toList();
  bool get _hasSelectedPlace =>
      _selectedTable != null || _selectedRoom != null || _selectedTakeaway;

  Map<String, String> get _placeNotes {
    final notes = <String, String>{};
    for (final order in _orders) {
      if (order.note.trim().isEmpty) continue;
      final key = order.isTakeaway
          ? 'takeaway'
          : order.roomNumber != null
          ? 'room_${order.roomNumber}'
          : order.tableNumber != null
          ? 'table_${order.tableNumber}'
          : null;
      if (key != null) notes[key] = order.note;
    }
    return notes;
  }

  int get _occupiedPlaces => _orders
      .where(
        (order) =>
            (order.tableNumber != null ||
                order.roomNumber != null ||
                order.isTakeaway) &&
            (order.items.isNotEmpty || order.hasRoomSession),
      )
      .length;

  @override
  void initState() {
    super.initState();
    _load();
    _roomTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _orders.any((order) => order.activeRoomSession != null)) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _roomTicker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final snapshot = await _repository.load();
      if (!mounted) return;
      setState(() {
        _orders
          ..clear()
          ..addAll(snapshot.orders);
        _sales
          ..clear()
          ..addAll(snapshot.sales);
        _products
          ..clear()
          ..addAll(snapshot.products);
        _dailyClosings
          ..clear()
          ..addAll(snapshot.dailyClosings);
        _expenses
          ..clear()
          ..addAll(snapshot.expenses);
        _notes
          ..clear()
          ..addAll(snapshot.notes);
        _roomHourlyRates
          ..clear()
          ..addAll(snapshot.roomHourlyRates);
        _placeNames
          ..clear()
          ..addAll(snapshot.placeNames);
        _tableCount = snapshot.tableCount;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('تعذر فتح قاعدة البيانات: $error');
    }
  }

  Future<void> _persistOrder(CafeOrder order) {
    final snapshot = order.copyWith(
      items: order.items.map((item) => item.copyWith()).toList(),
    );
    final write = _pendingWrites
        .catchError((Object _) {})
        .then((_) => _repository.saveOrder(snapshot));
    _pendingWrites = write;
    return write.catchError((Object error) {
      if (mounted) _snack('تعذر حفظ الطلب: $error');
    });
  }

  Future<void> _saveProduct(CafeProduct product) async {
    try {
      await _repository.saveProduct(product);
      if (!mounted) return;
      setState(() {
        final index = _products.indexWhere((item) => item.name == product.name);
        if (index < 0) {
          _products.add(product);
        } else {
          _products[index] = product;
        }
        _products.sort((first, second) => first.name.compareTo(second.name));
      });
      _snack('تم حفظ ${product.name} في المنيو');
    } catch (error) {
      _snack('تعذر حفظ الصنف: $error');
    }
  }

  Future<void> _renameProduct(String previousName, CafeProduct product) async {
    if (_products.any(
      (item) => item.name == product.name && item.name != previousName,
    )) {
      _snack('يوجد صنف آخر بنفس الاسم');
      return;
    }
    try {
      await _repository.saveProduct(product, previousName: previousName);
      if (!mounted) return;
      setState(() {
        final index = _products.indexWhere((item) => item.name == previousName);
        if (index >= 0) {
          _products[index] = product;
        } else {
          _products.add(product);
        }
        _products.sort((first, second) => first.name.compareTo(second.name));
      });
      _snack('تم تعديل الصنف وحفظ الاسم الجديد');
    } catch (error) {
      _snack('تعذر تعديل الصنف: $error');
    }
  }

  Future<void> _addStockProduct(CafeProduct product) async {
    if (_products.any((item) => item.name == product.name)) {
      _snack('يوجد صنف بنفس الاسم في المنيو');
      return;
    }
    await _saveProduct(product);
  }

  Future<void> _editStockProduct(
    CafeProduct original,
    CafeProduct updated,
  ) async {
    final duplicate = _products.any(
      (item) => item.name == updated.name && item.name != original.name,
    );
    if (duplicate) {
      _snack('يوجد صنف آخر بنفس الاسم');
      return;
    }
    try {
      await _repository.saveProduct(updated, previousName: original.name);
      if (!mounted) return;
      setState(() {
        final index = _products.indexWhere(
          (item) => item.name == original.name,
        );
        if (index >= 0) _products[index] = updated;
        _products.sort((first, second) => first.name.compareTo(second.name));
      });
      _snack('تم تعديل بيانات ${updated.name}');
    } catch (error) {
      _snack('تعذر تعديل الصنف: $error');
    }
  }

  Future<void> _saveTableName(int number, String name) async {
    try {
      await _repository.savePlaceName(
        isRoom: false,
        number: number,
        name: name,
      );
      if (!mounted) return;
      setState(() {
        final key = 'table_$number';
        if (name.trim().isEmpty) {
          _placeNames.remove(key);
        } else {
          _placeNames[key] = name.trim();
        }
        final activeIndex = _orders.indexWhere(
          (order) => order.tableNumber == number,
        );
        if (activeIndex >= 0) {
          _orders[activeIndex] = _orders[activeIndex].copyWith(
            label: name.trim().isEmpty ? 'ترابيزة $number' : name.trim(),
          );
        }
      });
      final activeOrder = _orders
          .where((order) => order.tableNumber == number)
          .firstOrNull;
      if (activeOrder != null) await _persistOrder(activeOrder);
      _snack('تم حفظ اسم الترابيزة');
    } catch (error) {
      _snack('تعذر حفظ اسم الترابيزة: $error');
    }
  }

  Future<void> _editPlaceNote(bool isRoom, int number, bool isTakeaway) async {
    final existing = _orders.where((order) {
      if (isTakeaway) return order.isTakeaway;
      if (isRoom) return order.roomNumber == number;
      return order.tableNumber == number;
    }).firstOrNull;
    final label = isTakeaway
        ? 'Take Away'
        : isRoom
        ? _placeNames['room_$number'] ?? 'أوضة بلايستيشن $number'
        : _placeNames['table_$number'] ?? 'ترابيزة $number';
    final order =
        existing ??
        CafeOrder(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          label: label,
          tableNumber: isTakeaway || isRoom ? null : number,
          roomNumber: isRoom ? number : null,
          isTakeaway: isTakeaway,
        );
    var noteText = order.note;
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('ملاحظة $label'),
        content: TextFormField(
          initialValue: order.note,
          autofocus: true,
          maxLines: 3,
          onChanged: (value) => noteText = value,
          decoration: const InputDecoration(hintText: 'اكتب ملاحظة للفاتورة'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, noteText.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (note == null || !mounted) return;
    final updated = order.copyWith(note: note);
    final index = _orders.indexWhere((item) => item.id == order.id);
    setState(() {
      if (index < 0) {
        _orders.add(updated);
      } else {
        _orders[index] = updated;
      }
    });
    await _persistOrder(updated);
  }

  Future<void> _restockProduct(
    CafeProduct product,
    int cartons,
    double purchasePrice,
  ) async {
    try {
      await _repository.restockProduct(product, cartons, purchasePrice);
      if (!mounted) return;
      setState(() {
        final index = _products.indexWhere((item) => item.name == product.name);
        if (index >= 0) {
          _products[index] = CafeProduct(
            product.name,
            product.category,
            product.price,
            product.icon,
            stockUnits:
                (product.stockUnits ?? 0) + cartons * product.unitsPerCarton!,
            unitsPerCarton: product.unitsPerCarton,
            purchasePricePerCarton: purchasePrice,
          );
        }
      });
      _snack('تمت إضافة $cartons كرتونة إلى مخزون ${product.name}');
    } catch (error) {
      _snack('تعذر إضافة المخزون: $error');
    }
  }

  Future<void> _deactivateProduct(CafeProduct product) async {
    final hasOpenOrder = _orders.any(
      (order) => order.items.any((item) => item.productName == product.name),
    );
    if (hasOpenOrder) {
      _snack('حصّل الطلب المفتوح الذي يحتوي على الصنف قبل إخفائه');
      return;
    }
    try {
      await _repository.setProductActive(product.name, false);
      if (!mounted) return;
      setState(
        () => _products.removeWhere((item) => item.name == product.name),
      );
      _snack('تم إخفاء ${product.name} من المنيو');
    } catch (error) {
      _snack('تعذر إخفاء الصنف: $error');
    }
  }

  Future<void> _closeDaily(DateTime day) async {
    if (_orders.any((order) => order.hasRoomSession)) {
      _snack('حصّل حسابات أوض البلايستيشن المفتوحة قبل إغلاق اليومية');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إغلاق يومية اليوم'),
        content: const Text(
          'سيتم حفظ إجمالي الفواتير منذ آخر إغلاق. يمكنك متابعة العمل وإغلاق يومية جديدة لاحقًا.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد الإغلاق'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _pendingWrites;
      final closing = await _repository.closeDaily(day);
      if (!mounted) return;
      setState(() {
        _dailyClosings.insert(0, closing);
      });
      _snack('تم إغلاق اليومية وحفظ ${closing.invoiceCount} فاتورة');
    } catch (error) {
      _snack('تعذر إغلاق اليومية: $error');
    }
  }

  Future<File> _createBackup() async {
    await _pendingWrites;
    return _repository.createBackup();
  }

  Future<CafeExpense> _addExpense({
    required double amount,
    required String note,
  }) async {
    final expense = await _repository.addExpense(amount: amount, note: note);
    if (mounted) setState(() => _expenses.insert(0, expense));
    return expense;
  }

  Future<void> _restoreBackup(File backup) async {
    await _pendingWrites;
    await _repository.restoreBackup(backup);
    await _load();
  }

  Future<CafeNote> _addNote(String text) async {
    final note = await _repository.addNote(text);
    if (!mounted) return note;
    setState(() => _notes.insert(0, note));
    _snack('تم حفظ الملاحظة');
    return note;
  }

  CafeOrder _ensurePlaceOrder({required bool isRoom, required int number}) {
    final found = _orders
        .where(
          (order) =>
              isRoom ? order.roomNumber == number : order.tableNumber == number,
        )
        .firstOrNull;
    if (found != null) return found;
    final order = CafeOrder(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      label: isRoom
          ? _placeNames['room_$number'] ?? 'أوضة بلايستيشن $number'
          : _placeNames['table_$number'] ?? 'ترابيزة $number',
      tableNumber: isRoom ? null : number,
      roomNumber: isRoom ? number : null,
    );
    _orders.add(order);
    return order;
  }

  CafeOrder _ensureTakeawayOrder() {
    final existing = _orders.where((order) => order.isTakeaway).firstOrNull;
    if (existing != null) return existing;
    final order = CafeOrder(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      label: 'Take Away',
      isTakeaway: true,
    );
    _orders.add(order);
    return order;
  }

  void _chooseProduct(CafeProduct product) {
    if (product.tracksStock && !_hasStockFor(product, 1)) {
      _snack('الكمية المتاحة من ${product.name} محجوزة في طلبات مفتوحة');
      return;
    }
    _addProduct(product);
  }

  void _addProduct(CafeProduct product) {
    final order = _selectedTakeaway
        ? _ensureTakeawayOrder()
        : _selectedRoom != null
        ? _ensurePlaceOrder(isRoom: true, number: _selectedRoom!)
        : _selectedTable != null
        ? _ensurePlaceOrder(isRoom: false, number: _selectedTable!)
        : null;
    if (order == null) return;
    final variant = CafeOrderItem(
      productName: product.name,
      quantity: 1,
      unitPrice: product.price,
    );
    final index = order.items.indexWhere((item) => item.sameVariant(variant));
    if (index >= 0) {
      final existing = order.items[index];
      order.items[index] = existing.copyWith(quantity: existing.quantity + 1);
    } else {
      order.items.add(variant);
    }
    setState(() {});
    _persistOrder(order);
  }

  void _addShishaStone(CafeOrder order) {
    final stone = _products
        .where((product) => product.name == 'حجر شيشة')
        .firstOrNull;
    if (stone == null) {
      _snack('أضف سعر حجر الشيشة من إدارة المنيو أولًا');
      return;
    }
    if (stone.tracksStock && !_hasStockFor(stone, 1)) {
      _snack('حجر الشيشة غير متاح في المخزون');
      return;
    }
    final variant = CafeOrderItem(
      productName: stone.name,
      quantity: 1,
      unitPrice: stone.price,
    );
    final index = order.items.indexWhere((item) => item.sameVariant(variant));
    if (index < 0) {
      order.items.add(variant);
    } else {
      order.items[index] = order.items[index].copyWith(
        quantity: order.items[index].quantity + 1,
      );
    }
    setState(() {});
    _persistOrder(order);
  }

  void _changeQuantity(CafeOrder order, CafeOrderItem current, int delta) {
    final index = order.items.indexWhere((item) => item.sameVariant(current));
    if (index < 0) return;
    final existing = order.items[index];
    final quantity = existing.quantity + delta;
    if (delta > 0) {
      final product = _products
          .where((item) => item.name == existing.productName)
          .firstOrNull;
      if (product != null && product.tracksStock && !_hasStockFor(product, 1)) {
        _snack('الكمية المتاحة من ${product.name} محجوزة في طلبات مفتوحة');
        return;
      }
    }
    if (quantity <= 0) {
      order.items.removeAt(index);
    } else {
      order.items[index] = existing.copyWith(quantity: quantity);
    }
    setState(() {});
    _persistOrder(order);
  }

  bool _hasStockFor(CafeProduct product, int requested) {
    final reserved = _orders.fold<int>(
      0,
      (sum, order) =>
          sum +
          order.items
              .where((item) => item.productName == product.name)
              .fold<int>(0, (quantity, item) => quantity + item.quantity),
    );
    return (product.stockUnits ?? 0) - reserved >= requested;
  }

  Future<void> _changeItemDiscount(CafeOrder order, CafeOrderItem item) async {
    final discount = await showCafeDiscountDialog(context, item);
    if (discount == null || !mounted) return;
    final index = order.items.indexWhere((value) => value.sameVariant(item));
    if (index < 0) return;
    setState(() {
      order.items[index] = order.items[index].copyWith(
        discountPerUnit: discount,
      );
    });
    await _persistOrder(order);
  }

  void _selectTakeaway() {
    setState(() {
      _selectedTable = null;
      _selectedRoom = null;
      _selectedTakeaway = true;
      _selectedNav = 0;
    });
  }

  void _selectPlace(bool isRoom, int number) async {
    if (isRoom) {
      final existingOrder = _orders
          .where((item) => item.roomNumber == number)
          .firstOrNull;
      if (existingOrder?.activeRoomSession == null) {
        final booking = await showCafeRoomBookingDialog(
          context,
          roomNumber: number,
          hourlyRates: _roomHourlyRates,
        );
        if (booking == null || !mounted) return;
        final currentOrder =
            existingOrder ?? _ensurePlaceOrder(isRoom: true, number: number);
        final sessionOrder = currentOrder.copyWith(
          roomSessions: [
            ...currentOrder.roomSessions,
            CafeRoomSession(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              mode: booking.mode,
              hourlyRate: booking.hourlyRate,
              startedAt: booking.startedAt,
            ),
          ],
        );
        final index = _orders.indexWhere((item) => item.id == sessionOrder.id);
        if (index >= 0) _orders[index] = sessionOrder;
        await _persistOrder(sessionOrder);
      }
    }
    setState(() {
      _selectedRoom = isRoom ? number : null;
      _selectedTable = isRoom ? null : number;
      _selectedTakeaway = false;
      _selectedNav = 0;
    });
  }

  Future<void> _checkout(CafeOrder order) async {
    if (order.items.isEmpty && !order.hasRoomSession) {
      _snack('أضف صنفًا للطلب أولاً');
      return;
    }
    final settledAt = DateTime.now();
    final settledOrder = order.copyWith(
      roomSessions: order.roomSessions
          .map(
            (session) => session.isActive
                ? session.copyWith(endedAt: settledAt)
                : session,
          )
          .toList(),
    );
    final confirm = await confirmCafeCheckout(context, settledOrder);
    if (confirm != true) return;
    try {
      await _pendingWrites;
      await _repository.completeSale(settledOrder);
      if (!mounted) return;
      setState(() {
        _orders.remove(order);
        for (final item in settledOrder.items) {
          final productIndex = _products.indexWhere(
            (product) =>
                product.name == item.productName && product.tracksStock,
          );
          if (productIndex < 0) continue;
          final product = _products[productIndex];
          _products[productIndex] = CafeProduct(
            product.name,
            product.category,
            product.price,
            product.icon,
            stockUnits: (product.stockUnits ?? 0) - item.quantity,
            unitsPerCarton: product.unitsPerCarton,
            purchasePricePerCarton: product.purchasePricePerCarton,
          );
        }
        _sales.insert(
          0,
          CafeSale.fromOrder(
            id: DateTime.now().microsecondsSinceEpoch,
            order: settledOrder,
            time: settledAt,
          ),
        );
        if (_selectedTable == order.tableNumber) _selectedTable = null;
        if (_selectedRoom == order.roomNumber) _selectedRoom = null;
        if (_selectedTakeaway && order.isTakeaway) _selectedTakeaway = false;
      });
      _snack('تم تسجيل الدفع وإغلاق الحساب');
    } catch (error) {
      _snack('تعذر إغلاق الحساب: $error');
    }
  }

  Future<void> _stopRoomSession(CafeOrder order) async {
    final activeSession = order.activeRoomSession;
    if (activeSession == null) return;
    final stoppedAt = DateTime.now();
    final stopped = order.copyWith(
      roomSessions: order.roomSessions
          .map(
            (session) => session.id == activeSession.id
                ? session.copyWith(endedAt: stoppedAt)
                : session,
          )
          .toList(),
    );
    final index = _orders.indexWhere((item) => item.id == order.id);
    if (index < 0) return;
    setState(() => _orders[index] = stopped);
    await _persistOrder(stopped);
  }

  Future<void> _resumeRoomSession(CafeOrder order) async {
    if (order.roomNumber == null ||
        order.activeRoomSession != null ||
        order.roomSessions.isEmpty) {
      return;
    }
    final previousSession = order.roomSessions.last;
    final resumed = order.copyWith(
      roomSessions: [
        ...order.roomSessions,
        CafeRoomSession(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          mode: previousSession.mode,
          hourlyRate: previousSession.hourlyRate,
          startedAt: DateTime.now(),
        ),
      ],
    );
    final index = _orders.indexWhere((item) => item.id == order.id);
    if (index < 0) return;
    setState(() => _orders[index] = resumed);
    await _persistOrder(resumed);
    _snack('تم استئناف الجلسة على نفس الفاتورة');
  }

  Future<void> _editRoomSessionTime(
    CafeOrder order,
    CafeRoomSession session,
  ) async {
    final startedAt = await chooseCafeRoomStartTime(
      context,
      initialDateTime: session.startedAt,
    );
    if (startedAt == null || !mounted) return;
    if (session.endedAt != null && startedAt.isAfter(session.endedAt!)) {
      _snack('وقت البداية لازم يكون قبل انتهاء الفترة');
      return;
    }
    final updated = order.copyWith(
      roomSessions: order.roomSessions
          .map(
            (item) => item.id == session.id
                ? item.copyWith(startedAt: startedAt)
                : item,
          )
          .toList(),
    );
    final index = _orders.indexWhere((item) => item.id == order.id);
    if (index < 0) return;
    setState(() => _orders[index] = updated);
    await _persistOrder(updated);
    _snack('تم تعديل وقت بداية فترة اللعب');
  }

  Future<void> _removeRoomSession(
    CafeOrder order,
    CafeRoomSession session,
  ) async {
    final mode = session.mode == 'multi' ? 'Multi' : 'Single';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('إلغاء فترة $mode'),
        content: Text(
          'سيتم حذف فترة $mode وقيمتها بالكامل من الفاتورة المفتوحة. هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('إلغاء الفترة'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final updated = order.copyWith(
      roomSessions: order.roomSessions
          .where((item) => item.id != session.id)
          .toList(),
    );
    try {
      final removeEmptyRoom =
          updated.roomSessions.isEmpty && updated.items.isEmpty;
      final write = _pendingWrites.catchError((Object _) {}).then((_) async {
        if (removeEmptyRoom) {
          await _repository.cancelRoomBooking(order);
        } else {
          await _repository.saveOrder(updated);
        }
      });
      _pendingWrites = write;
      await write;
      if (!mounted) return;
      if (removeEmptyRoom) {
        setState(() {
          _orders.removeWhere((item) => item.id == order.id);
          if (_selectedRoom == order.roomNumber) _selectedRoom = null;
        });
      } else {
        final index = _orders.indexWhere((item) => item.id == order.id);
        if (index >= 0) setState(() => _orders[index] = updated);
      }
      _snack('تم إلغاء فترة $mode وتحديث إجمالي الفاتورة');
    } catch (error) {
      _snack('تعذر إلغاء الفترة: $error');
    }
  }

  Future<void> _discountRoomSession(
    CafeOrder order,
    CafeRoomSession session,
  ) async {
    final currentCharge = session.chargeAt(DateTime.now());
    var discountText = session.discount > 0
        ? session.discount.toStringAsFixed(2)
        : '';
    final discount = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('خصم على ${session.mode == 'multi' ? 'Multi' : 'Single'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'قيمة الفترة الحالية: ${currentCharge.toStringAsFixed(2)} ج.م',
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: discountText,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (value) => discountText = value,
              decoration: const InputDecoration(
                labelText: 'قيمة الخصم بالجنيه',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(discountText.trim());
              if (value != null && value >= 0 && value <= currentCharge) {
                Navigator.pop(dialogContext, value);
              }
            },
            child: const Text('حفظ الخصم'),
          ),
        ],
      ),
    );
    if (discount == null || !mounted) return;
    final updated = order.copyWith(
      roomSessions: order.roomSessions
          .map(
            (item) => item.id == session.id
                ? item.copyWith(discount: discount)
                : item,
          )
          .toList(),
    );
    final index = _orders.indexWhere((item) => item.id == order.id);
    if (index < 0) return;
    setState(() => _orders[index] = updated);
    await _persistOrder(updated);
    _snack(
      discount == 0
          ? 'تم إلغاء خصم فترة اللعب'
          : 'تم تطبيق خصم ${discount.toStringAsFixed(2)} ج.م على الفترة',
    );
  }

  Future<void> _cancelRoomBooking(CafeOrder order) async {
    if (order.roomNumber == null) return;
    if (order.items.isNotEmpty) {
      _snack('احصل حساب المشروبات أولًا قبل إلغاء حجز الأوضة');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إلغاء حجز الأوضة'),
        content: Text(
          'سيتم حذف فترات اللعب غير المحصلة وإتاحة أوضة البلايستيشن ${order.roomNumber} من جديد. هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('إلغاء الحجز'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _pendingWrites;
      await _repository.cancelRoomBooking(order);
      if (!mounted) return;
      setState(() {
        _orders.removeWhere((item) => item.id == order.id);
        if (_selectedRoom == order.roomNumber) _selectedRoom = null;
      });
      _snack('تم إلغاء الحجز وإتاحة الأوضة');
    } catch (error) {
      _snack('تعذر إلغاء الحجز: $error');
    }
  }

  Future<void> _changeRoomMode(CafeOrder order) async {
    final room = order.roomNumber;
    final activeSession = order.activeRoomSession;
    if (room == null || activeSession == null) return;
    final booking = await showCafeRoomBookingDialog(
      context,
      roomNumber: room,
      hourlyRates: _roomHourlyRates,
    );
    if (booking == null || !mounted || booking.mode == activeSession.mode) {
      return;
    }
    final changedAt = DateTime.now();
    final updated = order.copyWith(
      roomSessions: [
        ...order.roomSessions.map(
          (session) => session.id == activeSession.id
              ? session.copyWith(endedAt: changedAt)
              : session,
        ),
        CafeRoomSession(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          mode: booking.mode,
          hourlyRate: booking.hourlyRate,
          startedAt: changedAt,
        ),
      ],
    );
    final index = _orders.indexWhere((item) => item.id == updated.id);
    if (index < 0) return;
    setState(() => _orders[index] = updated);
    await _persistOrder(updated);
    _snack(
      'تم تغيير الجلسة إلى ${booking.mode == 'multi' ? 'Multi' : 'Single'} وإضافتها لنفس الفاتورة',
    );
  }

  Future<void> _saveRoomHourlyRate(int room, String mode, double rate) async {
    try {
      await _repository.saveRoomHourlyRate(room, mode, rate);
      if (!mounted) return;
      setState(() => _roomHourlyRates['room_${room}_$mode'] = rate);
      _snack('تم حفظ سعر ${mode == 'multi' ? 'Multi' : 'Single'} لأوضة $room');
    } catch (error) {
      _snack('تعذر حفظ سعر الأوضة: $error');
    }
  }

  Future<void> _saveRoomName(int number, String name) async {
    try {
      await _repository.savePlaceName(isRoom: true, number: number, name: name);
      if (!mounted) return;
      final key = 'room_$number';
      setState(() {
        if (name.trim().isEmpty) {
          _placeNames.remove(key);
        } else {
          _placeNames[key] = name.trim();
        }
        final activeIndex = _orders.indexWhere(
          (order) => order.roomNumber == number,
        );
        if (activeIndex >= 0) {
          _orders[activeIndex] = _orders[activeIndex].copyWith(
            label: name.trim().isEmpty ? 'أوضة بلايستيشن $number' : name.trim(),
          );
        }
      });
      final activeOrder = _orders
          .where((order) => order.roomNumber == number)
          .firstOrNull;
      if (activeOrder != null) await _persistOrder(activeOrder);
      _snack('تم حفظ اسم الأوضة');
    } catch (error) {
      _snack('تعذر حفظ اسم الأوضة: $error');
    }
  }

  Future<void> _tableSettings() async {
    if (!await _requireAdmin()) return;
    var count = _tableCount;
    final minimumCount = _orders
        .where((order) => order.tableNumber != null)
        .fold<int>(
          1,
          (highest, order) =>
              order.tableNumber! > highest ? order.tableNumber! : highest,
        );
    final value = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text(
            'إعداد الترابيزات',
            textDirection: TextDirection.rtl,
          ),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('عدد الترابيزات'),
              const SizedBox(width: 14),
              IconButton(
                onPressed: count > minimumCount
                    ? () => update(() => count--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$count'),
              IconButton(
                onPressed: count < 100 ? () => update(() => count++) : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, count),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (value != null) {
      setState(() => _tableCount = value);
      try {
        await _repository.setTableCount(value);
      } catch (error) {
        _snack('تعذر حفظ الإعداد: $error');
      }
    }
  }

  Future<bool> _requireAdmin() async {
    if (_adminUnlocked) return true;
    final isSetup = !await _repository.hasAdminPassword();
    if (!mounted) return false;
    final password = await showAdminPasswordDialog(context, setup: isSetup);
    if (password == null) return false;
    if (isSetup) {
      await _repository.setAdminPassword(password);
      _snack('تم إنشاء كلمة مرور الأدمن');
    } else if (!await _repository.verifyAdminPassword(password)) {
      _snack('كلمة المرور غير صحيحة');
      return false;
    }
    if (!mounted) return false;
    setState(() => _adminUnlocked = true);
    return true;
  }

  Future<void> _selectNavigation(int index) async {
    if (index >= 3 && index != 6 && !await _requireAdmin()) return;
    if (!mounted) return;
    setState(() {
      _selectedNav = index;
      if (index != 0) {
        _selectedTable = null;
        _selectedRoom = null;
        _selectedTakeaway = false;
      }
    });
  }

  void _snack(String message) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, textAlign: TextAlign.center),
      behavior: SnackBarBehavior.floating,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.cream,
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.green),
              )
            : Row(
                children: [
                  CafeSidebar(
                    selected: _selectedNav,
                    onSelect: _selectNavigation,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        _header(),
                        Expanded(
                          child: switch (_selectedNav) {
                            1 => CafeTablesPage(
                              tableCount: _tableCount,
                              orders: _orders,
                              onSelect: _selectPlace,
                              onSelectTakeaway: _selectTakeaway,
                              placeNames: _placeNames,
                              placeNotes: _placeNotes,
                              onSaveTableName: _adminUnlocked
                                  ? _saveTableName
                                  : null,
                              onEditPlaceNote: _editPlaceNote,
                            ),
                            2 => CafeReportsPage(
                              sales: _sales,
                              dailyClosings: _dailyClosings,
                              expenses: _expenses,
                              onAddExpense: _addExpense,
                              onCloseDay: _closeDaily,
                              canCloseDay: true,
                              canViewHistory: _adminUnlocked,
                            ),
                            3 => CafeMenuPage(
                              products: _products,
                              onSaveProduct: _saveProduct,
                              onRenameProduct: _renameProduct,
                              onDeactivateProduct: _deactivateProduct,
                              roomHourlyRates: _roomHourlyRates,
                              onSaveRoomHourlyRate: _saveRoomHourlyRate,
                              roomNames: _placeNames,
                              onSaveRoomName: _saveRoomName,
                            ),
                            4 => CafeInventoryPage(
                              products: _products,
                              onAddStockProduct: _addStockProduct,
                              onEditStockProduct: _adminUnlocked
                                  ? _editStockProduct
                                  : null,
                              onRestock: _restockProduct,
                              onLoadSales: _repository.loadInventorySales,
                            ),
                            5 => CafeBackupPage(
                              backupDirectory: _repository.backupsDirectoryPath,
                              onCreateBackup: _createBackup,
                              onListBackups: _repository.listBackups,
                              onRestoreBackup: _restoreBackup,
                              canManageBackups: _adminUnlocked,
                            ),
                            6 => CafeNotesPage(notes: _notes, onAdd: _addNote),
                            _ => wide ? _wideCashier() : _compactCashier(),
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _header() => Container(
    height: 66,
    padding: const EdgeInsets.symmetric(horizontal: 22),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: Color(0xFFE8E8E2))),
    ),
    child: Row(
      children: [
        const Icon(Icons.wb_sunny_outlined, color: AppColors.orange),
        const SizedBox(width: 8),

        const Spacer(),
        if (_adminUnlocked)
          TextButton.icon(
            onPressed: () => setState(() {
              _adminUnlocked = false;
              _selectedNav = 0;
              _selectedTable = null;
              _selectedRoom = null;
              _selectedTakeaway = false;
            }),
            icon: const Icon(Icons.lock_outline),
            label: const Text('خروج الأدمن'),
          )
        else
          TextButton.icon(
            onPressed: _requireAdmin,
            icon: const Icon(Icons.admin_panel_settings_outlined),
            label: const Text('دخول الأدمن'),
          ),
        IconButton(
          tooltip: 'إعداد الترابيزات (للأدمن)',
          onPressed: _tableSettings,
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    ),
  );

  Widget _wideCashier() => Row(
    children: [
      Expanded(child: _productBrowser(placeSelector: _placeSelector())),
      SizedBox(width: 350, child: _orderPanel()),
    ],
  );
  Widget _compactCashier() => Column(
    children: [
      if (!_hasSelectedPlace) SizedBox(height: 142, child: _placeSelector()),
      Expanded(child: _productBrowser()),
      if (_hasSelectedPlace) SizedBox(height: 280, child: _orderPanel()),
    ],
  );

  Widget _productBrowser({Widget? placeSelector}) => CashierProductBrowser(
    searchController: _searchController,
    onSearchChanged: (value) => setState(() => _search = value.trim()),
    category: _category,
    onCategoryChanged: (value) => setState(() => _category = value),
    products: _visibleProducts,
    hasSelectedPlace: _hasSelectedPlace,
    activePlaceCount: _occupiedPlaces,
    totalPlaceCount: _tableCount + 3,
    onChooseProduct: _chooseProduct,
    placeSelector: placeSelector,
  );
  Widget _placeSelector() => CafePlaceStrip(
    tableCount: _tableCount,
    orders: _orders,
    selectedTable: _selectedTable,
    selectedRoom: _selectedRoom,
    selectedTakeaway: _selectedTakeaway,
    onSelect: _selectPlace,
    onSelectTakeaway: _selectTakeaway,
    placeNames: _placeNames,
    placeNotes: _placeNotes,
    onPlaceNoteTap: _editPlaceNote,
  );
  Widget _orderPanel() {
    final noPlaceSelected = !_hasSelectedPlace;
    final order = noPlaceSelected ? null : _activeOrder;
    final title = order != null
        ? (order.isTakeaway ? 'Take Away' : order.label)
        : _selectedRoom != null
        ? _placeNames['room_$_selectedRoom'] ?? 'أوضة بلايستيشن $_selectedRoom'
        : _selectedTable != null
        ? _placeNames['table_$_selectedTable'] ?? 'ترابيزة $_selectedTable'
        : 'الطلبات';
    return CafeOrderPanel(
      title: title,
      order: order,
      onQuantityChange: (item, delta) {
        if (order != null) _changeQuantity(order, item, delta);
      },
      onDiscount: (item) {
        if (order != null) _changeItemDiscount(order, item);
      },
      onCheckout: _checkout,
      onStopRoomSession: _stopRoomSession,
      onResumeRoomSession: _resumeRoomSession,
      onChangeRoomMode: _changeRoomMode,
      onCancelRoomBooking: _cancelRoomBooking,
      onRemoveRoomSession: _removeRoomSession,
      onAddShishaStone: _addShishaStone,
      onDiscountRoomSession: _discountRoomSession,
      onEditRoomSessionTime: _editRoomSessionTime,
    );
  }
}
