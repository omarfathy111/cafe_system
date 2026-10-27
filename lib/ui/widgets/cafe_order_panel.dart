import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/cafe_order.dart';
import 'cashier_components.dart';

class CafeOrderPanel extends StatelessWidget {
  const CafeOrderPanel({
    super.key,
    required this.title,
    required this.order,
    required this.onQuantityChange,
    required this.onDiscount,
    required this.onCheckout,
    required this.onStopRoomSession,
    required this.onChangeRoomMode,
    required this.onCancelRoomBooking,
  });

  final String title;
  final CafeOrder? order;
  final void Function(CafeOrderItem item, int delta) onQuantityChange;
  final ValueChanged<CafeOrderItem> onDiscount;
  final ValueChanged<CafeOrder> onCheckout;
  final ValueChanged<CafeOrder> onStopRoomSession;
  final ValueChanged<CafeOrder> onChangeRoomMode;
  final ValueChanged<CafeOrder> onCancelRoomBooking;

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.receipt_long, color: AppColors.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
              ),
              if (order?.hasRoomSession == true)
                IconButton(
                  tooltip: 'إلغاء حجز الأوضة',
                  onPressed: () => onCancelRoomBooking(order!),
                  icon: const Icon(
                    Icons.event_busy_outlined,
                    color: Colors.redAccent,
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: order == null
              ? const Center(
                  child: Text(
                    'أضف أصنافًا للطلب',
                    style: TextStyle(color: Colors.black45),
                  ),
                )
              : Column(
                  children: [
                    if (order!.roomSessions.isNotEmpty)
                      SizedBox(
                        height: (order!.roomSessions.length * 58.0).clamp(
                          58.0,
                          145.0,
                        ).toDouble(),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          itemCount: order!.roomSessions.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final session = order!.roomSessions[index];
                            final now = DateTime.now();
                            final endedAt = session.endedAt ?? now;
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                session.mode == 'multi'
                                    ? Icons.group_outlined
                                    : Icons.person_outline,
                                color: AppColors.green,
                              ),
                              title: Text(
                                '${session.mode == 'multi' ? 'Multi' : 'Single'} • ${_formatClock(session.startedAt)}–${_formatClock(endedAt)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              subtitle: Text(
                                '${_formatDuration(session.durationMinutesAt(now))} × ${session.hourlyRate.toStringAsFixed(2)} ج.م/ساعة${session.isActive ? ' • جارية' : ''}',
                                style: const TextStyle(fontSize: 10),
                              ),
                              trailing: Text(
                                '${session.chargeAt(now).toStringAsFixed(2)} ج.م',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    Expanded(
                      child: CafeOrderContents(
                        order: order!,
                        onChange: onQuantityChange,
                        onDiscount: onDiscount,
                      ),
                    ),
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (order?.hasRoomSession == true) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F5F2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.sports_esports, color: AppColors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order!.activeRoomSession == null
                                  ? 'الجلسة متوقفة'
                                  : '${order!.activeRoomSession!.mode == 'multi' ? 'Multi' : 'Single'} • ${order!.activeRoomSession!.hourlyRate.toStringAsFixed(2)} ج.م/ساعة',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'إجمالي اللعب ${_formatDuration(order!.roomDurationMinutesAt(DateTime.now()))} • ${order!.roomCharge.toStringAsFixed(2)} ج.م',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                            if (order!.activeRoomSession != null)
                              Text(
                                'بدأت الفترة ${_formatTimestamp(order!.activeRoomSession!.startedAt)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (order!.activeRoomSession != null)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () => onChangeRoomMode(order!),
                              child: const Text('تغيير الوضع'),
                            ),
                            TextButton(
                              onPressed: () => onStopRoomSession(order!),
                              child: const Text('إنهاء'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
              Row(
                children: [
                  const Expanded(child: Text('الإجمالي')),
                  Text(
                    '${order?.total.toStringAsFixed(2) ?? '0.00'} ج.م',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      order == null ||
                          (order!.items.isEmpty && !order!.hasRoomSession)
                      ? null
                      : () => onCheckout(order!),
                  icon: const Icon(Icons.point_of_sale),
                  label: const Text('تحصيل وإغلاق الحساب'),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

String _formatDuration(int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return '${hours.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
}

String _formatTimestamp(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';

String _formatClock(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
