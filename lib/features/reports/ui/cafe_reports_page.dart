import 'dart:async';

import 'package:cafe_system/core/utils/app_constants.dart';
import 'package:cafe_system/core/widgets/cafe_page_heading.dart';
import 'package:cafe_system/features/orders_history/data/cafe_sale.dart';
import 'package:cafe_system/features/orders_history/data/cafe_sale_item.dart';
import 'package:cafe_system/features/orders_history/ui/cafe_invoice_editor_dialog.dart';
import 'package:cafe_system/features/pos/ui/widgets/cashier_components.dart';
import 'package:cafe_system/features/reports/data/cafe_daily_closing.dart';
import 'package:cafe_system/features/reports/data/cafe_expense.dart';
import 'package:flutter/material.dart';

class CafeReportsPage extends StatefulWidget {
  const CafeReportsPage({
    super.key,
    required this.sales,
    required this.dailyClosings,
    required this.onCloseDay,
    required this.canCloseDay,
    this.expenses = const [],
    this.onAddExpense,
    this.canViewHistory = false,
    this.onEditSale,
    this.onDeleteSale,
    this.onEditExpense,
    this.onDeleteExpense,
  });
  final List<CafeSale> sales;
  final List<CafeDailyClosing> dailyClosings;
  final Future<void> Function(DateTime day) onCloseDay;
  final bool canCloseDay;
  final bool canViewHistory;
  final Future<void> Function(
    CafeSale sale,
    List<CafeSaleItem> items,
    String note,
  )?
  onEditSale;
  final Future<bool> Function(CafeSale sale)? onDeleteSale;
  final Future<void> Function(CafeExpense expense, double amount, String note)?
  onEditExpense;
  final Future<bool> Function(CafeExpense expense)? onDeleteExpense;
  final List<CafeExpense> expenses;
  final Future<CafeExpense> Function({
    required double amount,
    required String note,
  })?
  onAddExpense;

  @override
  State<CafeReportsPage> createState() => _CafeReportsPageState();
}

class _CafeReportsPageState extends State<CafeReportsPage> {
  DateTime? _selectedDay;
  int? _selectedClosingId;
  final Set<int> _hiddenSaleIds = {};
  final Set<int> _hiddenExpenseIds = {};
  Timer? _midnightRefresh;

  @override
  void initState() {
    super.initState();
    _scheduleMidnightRefresh();
  }

  void _scheduleMidnightRefresh() {
    final now = DateTime.now();
    final nextDay = DateTime(now.year, now.month, now.day + 1);
    _midnightRefresh = Timer(
      nextDay.difference(now) + const Duration(seconds: 1),
      () {
        if (!mounted) return;
        if (_selectedDay == null) setState(() {});
        _scheduleMidnightRefresh();
      },
    );
  }

  @override
  void dispose() {
    _midnightRefresh?.cancel();
    super.dispose();
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
  DateTime _addDays(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  void _selectDay(DateTime day) {
    if (!mounted) return;
    final normalized = _dateOnly(day);
    if (!widget.canViewHistory && normalized != _dateOnly(DateTime.now())) {
      return;
    }
    setState(() {
      _selectedDay = normalized == _dateOnly(DateTime.now())
          ? null
          : normalized;
      _selectedClosingId = null;
    });
  }

  Future<void> _chooseDay(DateTime firstDay, DateTime today) async {
    final selected = _selectedDay ?? today;
    final picked = await showDatePicker(
      context: context,
      initialDate: selected,
      firstDate: firstDay.isAfter(today) ? today : firstDay,
      lastDate: today,
      helpText: 'اختر يوم الفواتير',
    );
    if (picked != null) _selectDay(picked);
  }

  Future<void> _recordExpense() async {
    final expenseDetails = await showDialog<(double, String)>(
      context: context,
      builder: (_) => const _CafeExpenseDialog(),
    );
    final addExpense = widget.onAddExpense;
    if (expenseDetails == null || !mounted || addExpense == null) return;
    try {
      await addExpense(amount: expenseDetails.$1, note: expenseDetails.$2);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذر حفظ المصروف: $error')));
      }
    }
  }

  Future<void> _editInvoice(CafeSale sale) async {
    final result = await showCafeInvoiceEditor(context, sale);
    if (result != null && mounted) {
      await widget.onEditSale?.call(sale, result.$1, result.$2);
    }
  }

  Future<void> _deleteInvoice(CafeSale sale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الفاتورة؟'),
        content: Text(
          'سيتم حذف فاتورة ${sale.label} بقيمة ${sale.total.toStringAsFixed(2)} ج.م وإرجاع أصناف المخزون المسجلة بها.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _hiddenSaleIds.add(sale.id));
    final deleted = await widget.onDeleteSale?.call(sale) ?? false;
    if (!deleted && mounted) {
      setState(() => _hiddenSaleIds.remove(sale.id));
    }
  }

  Future<void> _editExpense(CafeExpense expense) async {
    final result = await showDialog<(double, String)>(
      context: context,
      builder: (_) => _CafeExpenseDialog(expense: expense),
    );
    if (result != null && mounted) {
      await widget.onEditExpense?.call(expense, result.$1, result.$2);
    }
  }

  Future<void> _deleteExpense(CafeExpense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف المصروف؟'),
        content: Text(
          'سيتم حذف مصروف "${expense.note}" بقيمة ${expense.amount.toStringAsFixed(2)} ج.م.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => _hiddenExpenseIds.add(expense.id));
      final deleted = await widget.onDeleteExpense?.call(expense) ?? false;
      if (!deleted && mounted) {
        setState(() => _hiddenExpenseIds.remove(expense.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = _dateOnly(now);
    final visibleSales =
        (widget.canViewHistory
                ? widget.sales
                : widget.sales
                      .where((sale) => _dateOnly(sale.time) == today)
                      .toList())
            .where((sale) => !_hiddenSaleIds.contains(sale.id))
            .toList();
    final firstSale = visibleSales.isEmpty
        ? today
        : _dateOnly(
            visibleSales
                .map((sale) => sale.time)
                .reduce((first, date) => date.isBefore(first) ? date : first),
          );
    final selectedDay = _selectedDay ?? today;
    final dayNumber = selectedDay.difference(firstSale).inDays + 1;
    final dayClosings =
        widget.dailyClosings
            .where(
              (item) =>
                  item.dateKey == _dateKey(selectedDay) &&
                  (widget.canViewHistory || selectedDay == today),
            )
            .toList()
          ..sort((a, b) => b.closedAt.compareTo(a.closedAt));
    final selectedClosing = dayClosings
        .where((item) => item.id == _selectedClosingId)
        .firstOrNull;
    final olderClosings = [...dayClosings]
      ..sort((a, b) => a.closedAt.compareTo(b.closedAt));
    final selectedClosingIndex = selectedClosing == null
        ? -1
        : olderClosings.indexWhere((item) => item.id == selectedClosing.id);
    final periodStart = selectedClosingIndex > 0
        ? olderClosings[selectedClosingIndex - 1].closedAt
        : DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    final selectedSales = visibleSales.where((sale) {
      if (_dateOnly(sale.time) != selectedDay) return false;
      if (selectedClosing == null) return true;
      return sale.time.isAfter(periodStart) &&
          !sale.time.isAfter(selectedClosing.closedAt);
    }).toList();
    final visibleExpenses =
        (widget.canViewHistory
                ? widget.expenses
                : widget.expenses
                      .where(
                        (expense) => _dateOnly(expense.incurredAt) == today,
                      )
                      .toList())
            .where((expense) => !_hiddenExpenseIds.contains(expense.id))
            .toList();
    final selectedExpenses = visibleExpenses.where((expense) {
      if (_dateOnly(expense.incurredAt) != selectedDay) return false;
      if (selectedClosing == null) return true;
      return expense.incurredAt.isAfter(periodStart) &&
          !expense.incurredAt.isAfter(selectedClosing.closedAt);
    }).toList();
    final grossSales = selectedSales.fold<double>(
      0,
      (sum, sale) => sum + sale.total,
    );
    final expenseTotal = selectedExpenses.fold<double>(
      0,
      (sum, expense) => sum + expense.amount,
    );
    final total = grossSales - expenseTotal;
    final entries = <({DateTime time, CafeSale? sale, CafeExpense? expense})>[
      for (final sale in selectedSales)
        (time: sale.time, sale: sale, expense: null),
      for (final expense in selectedExpenses)
        (time: expense.incurredAt, sale: null, expense: expense),
    ]..sort((a, b) => b.time.compareTo(a.time));
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CafePageHeading(title: 'التقارير'),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              CafeMetric(
                label: 'إجمالي المبيعات',
                value: '${grossSales.toStringAsFixed(0)} ج.م',
                icon: Icons.point_of_sale,
              ),
              CafeMetric(
                label:
                    'صافي ${selectedDay == today ? 'اليوم' : 'اليوم المحدد'}',
                value: '${total.toStringAsFixed(0)} ج.م',
                icon: Icons.payments,
              ),
              CafeMetric(
                label: 'إجمالي المصروفات',
                value: '${expenseTotal.toStringAsFixed(0)} ج.م',
                icon: Icons.shopping_bag_outlined,
              ),
              CafeMetric(
                label: 'عدد الفواتير',
                value: '${selectedSales.length}',
                icon: Icons.receipt_long,
              ),
              CafeMetric(
                label: 'اليوم في السجل',
                value: dayNumber < 1 ? '1' : '$dayNumber',
                icon: Icons.event_available,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  selectedClosing == null
                      ? 'الفواتير والمصروفات'
                      : 'حركة اليومية حتى ${selectedClosing.closedAt.hour.toString().padLeft(2, '0')}:${selectedClosing.closedAt.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: widget.onAddExpense == null ? null : _recordExpense,
                icon: const Icon(Icons.add),
                label: const Text('تسجيل مصروف'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                if (widget.canViewHistory)
                  IconButton(
                    tooltip: 'اليوم التالي',
                    onPressed: selectedDay.isBefore(today)
                        ? () => _selectDay(_addDays(selectedDay, 1))
                        : null,
                    icon: const Icon(Icons.arrow_back),
                  ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: widget.canViewHistory
                        ? () => _chooseDay(DateTime(2000), today)
                        : null,
                    icon: const Icon(Icons.calendar_month),
                    label: Text(
                      '${selectedDay == today ? 'اليوم' : 'فواتير يوم'} ${_formatDate(selectedDay)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (widget.canViewHistory)
                  IconButton(
                    tooltip: 'اليوم السابق',
                    onPressed: selectedDay.isAfter(DateTime(2000))
                        ? () => _selectDay(_addDays(selectedDay, -1))
                        : null,
                    icon: const Icon(Icons.arrow_forward),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (selectedDay == today && widget.canCloseDay)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.icon(
                onPressed: () => widget.onCloseDay(today),
                icon: const Icon(Icons.lock_clock),
                label: const Text('إغلاق يومية اليوم'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB3261E),
                ),
              ),
            ),
          if (dayClosings.isNotEmpty)
            SizedBox(
              height: 78,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: dayClosings.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final closing = dayClosings[index];
                  final selected = _selectedClosingId == closing.id;
                  return SizedBox(
                    width: 205,
                    child: Card(
                      margin: EdgeInsets.zero,
                      color: selected
                          ? const Color(0xFFD6E9DF)
                          : const Color(0xFFEAF2ED),
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          selected ? Icons.check_circle : Icons.lock,
                          color: AppColors.green,
                        ),
                        title: Text(
                          'يومية ${closing.closedAt.hour.toString().padLeft(2, '0')}:${closing.closedAt.minute.toString().padLeft(2, '0')}',
                        ),
                        subtitle: Text(
                          '${closing.invoiceCount} فاتورة • صافي ${closing.total.toStringAsFixed(2)} ج.م',
                        ),
                        onTap: () =>
                            setState(() => _selectedClosingId = closing.id),
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: entries.isEmpty
                ? const Center(
                    child: Text('لا توجد فواتير أو مصروفات في الفترة المحددة'),
                  )
                : ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final expense = entry.expense;
                      if (expense != null) {
                        return Card(
                          color: const Color(0xFFFFF7F5),
                          child: ListTile(
                            leading: const Icon(
                              Icons.shopping_bag_outlined,
                              color: Color(0xFFB3261E),
                            ),
                            title: Text('مصروف: ${expense.note}'),
                            subtitle: Text(
                              '${expense.incurredAt.hour.toString().padLeft(2, '0')}:${expense.incurredAt.minute.toString().padLeft(2, '0')}',
                            ),
                            trailing: widget.canViewHistory
                                ? Wrap(
                                    //    MainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        '- ${expense.amount.toStringAsFixed(2)} ج.م',
                                        style: const TextStyle(
                                          color: Color(0xFFB3261E),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'تعديل المصروف',
                                        onPressed: widget.onEditExpense == null
                                            ? null
                                            : () => _editExpense(expense),
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          color: AppColors.green,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'حذف المصروف',
                                        onPressed:
                                            widget.onDeleteExpense == null
                                            ? null
                                            : () => _deleteExpense(expense),
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    '- ${expense.amount.toStringAsFixed(2)} ج.م',
                                    style: const TextStyle(
                                      color: Color(0xFFB3261E),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        );
                      }
                      final sale = entry.sale!;
                      return Card(
                        color: Colors.white,
                        child: ListTile(
                          leading: const Icon(
                            Icons.receipt,
                            color: AppColors.green,
                          ),
                          title: Text(sale.label),
                          subtitle: Text(
                            '${sale.time.hour.toString().padLeft(2, '0')}:${sale.time.minute.toString().padLeft(2, '0')} • ${sale.items.entries.map((item) => '${item.key} × ${item.value}').join('، ')}${sale.roomSessions.isNotEmpty || sale.roomStartedAt == null ? '' : ' • جلسة البلايستيشن: ${_formatTimestamp(sale.roomStartedAt!)} ← ${sale.roomEndedAt == null ? 'مستمرة' : _formatTimestamp(sale.roomEndedAt!)}'}${sale.note.isEmpty ? '' : ' • ملاحظة: ${sale.note}'}',
                          ),
                          trailing: widget.canViewHistory
                              ? Wrap(
                                  //   mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      '${sale.total.toStringAsFixed(0)} ج.م',
                                    ),
                                    IconButton(
                                      tooltip: 'تعديل الفاتورة',
                                      onPressed: widget.onEditSale == null
                                          ? null
                                          : () => _editInvoice(sale),
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        color: AppColors.green,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'حذف الفاتورة',
                                      onPressed: widget.onDeleteSale == null
                                          ? null
                                          : () => _deleteInvoice(sale),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                  ],
                                )
                              : Text('${sale.total.toStringAsFixed(0)} ج.م'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';
}

class _CafeExpenseDialog extends StatefulWidget {
  const _CafeExpenseDialog({this.expense});

  final CafeExpense? expense;

  @override
  State<_CafeExpenseDialog> createState() => _CafeExpenseDialogState();
}

class _CafeExpenseDialogState extends State<_CafeExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    if (expense != null) {
      _amountController.text = expense.amount.toStringAsFixed(2);
      _noteController.text = expense.note;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amountController.text.trim());
    Navigator.pop(context, (amount, _noteController.text.trim()));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.expense == null ? 'تسجيل مصروف' : 'تعديل المصروف'),
    content: Form(
      key: _formKey,
      child: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _amountController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'المبلغ بالجنيه',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              validator: (value) {
                final amount = double.tryParse(value?.trim() ?? '');
                return amount == null || !amount.isFinite || amount <= 0
                    ? 'أدخل مبلغًا صحيحًا أكبر من صفر'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'ملاحظة (مثال: شراء علبة شاي)',
                prefixIcon: Icon(Icons.edit_note),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'اكتب سبب المصروف'
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      FilledButton(onPressed: _save, child: const Text('حفظ المصروف')),
    ],
  );
}
