import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/cafe_daily_closing.dart';
import '../../data/models/cafe_sale.dart';
import 'cafe_page_heading.dart';
import 'cashier_components.dart';

class CafeReportsPage extends StatefulWidget {
  const CafeReportsPage({
    super.key,
    required this.sales,
    required this.dailyClosings,
    required this.onCloseDay,
    required this.canCloseDay,
    this.canViewHistory = false,
  });
  final List<CafeSale> sales;
  final List<CafeDailyClosing> dailyClosings;
  final Future<void> Function(DateTime day) onCloseDay;
  final bool canCloseDay;
  final bool canViewHistory;

  @override
  State<CafeReportsPage> createState() => _CafeReportsPageState();
}

class _CafeReportsPageState extends State<CafeReportsPage> {
  DateTime? _selectedDay;
  int? _selectedClosingId;
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

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = _dateOnly(now);
    final visibleSales = widget.canViewHistory
        ? widget.sales
        : widget.sales.where((sale) => _dateOnly(sale.time) == today).toList();
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
    final total = selectedSales.fold<double>(
      0,
      (sum, sale) => sum + sale.total,
    );
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
                label:
                    'مبيعات ${selectedDay == today ? 'اليوم' : 'اليوم المحدد'}',
                value: '${total.toStringAsFixed(0)} ج.م',
                icon: Icons.payments,
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
          Text(
            selectedClosing == null
                ? 'فواتير اليوم'
                : 'فواتير اليومية حتى ${selectedClosing.closedAt.hour.toString().padLeft(2, '0')}:${selectedClosing.closedAt.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                          '${closing.invoiceCount} فاتورة • ${closing.total.toStringAsFixed(2)} ج.م',
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
            child: selectedSales.isEmpty
                ? const Center(child: Text('لا توجد فواتير في هذا اليوم'))
                : ListView.builder(
                    itemCount: selectedSales.length,
                    itemBuilder: (context, index) {
                      final sale = selectedSales[index];
                      return Card(
                        color: Colors.white,
                        child: ListTile(
                          leading: const Icon(
                            Icons.receipt,
                            color: AppColors.green,
                          ),
                          title: Text(sale.label),
                          subtitle: Text(
                            '${sale.time.hour.toString().padLeft(2, '0')}:${sale.time.minute.toString().padLeft(2, '0')} • ${sale.items.entries.map((item) => '${item.key} × ${item.value}').join('، ')}${sale.roomSessions.isNotEmpty || sale.roomStartedAt == null ? '' : ' • جلسة البلايستيشن: ${_formatTimestamp(sale.roomStartedAt!)} ← ${sale.roomEndedAt == null ? 'مستمرة' : _formatTimestamp(sale.roomEndedAt!)}'}',
                          ),
                          trailing: Text(
                            '${sale.total.toStringAsFixed(0)} ج.م',
                          ),
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
