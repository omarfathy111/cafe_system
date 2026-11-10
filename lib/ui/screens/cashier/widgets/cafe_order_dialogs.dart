import 'package:cafe_system/core/utils/app_constants.dart';
import 'package:cafe_system/models/cafe_order.dart';
import 'package:flutter/material.dart';

Future<bool?> confirmCafeCheckout(BuildContext context, CafeOrder order) =>
    showDialog<bool>(
      context: context,
      builder: (_) => CafeCheckoutDialog(order: order),
    );

class CafeCheckoutDialog extends StatelessWidget {
  const CafeCheckoutDialog({super.key, required this.order});
  final CafeOrder order;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('تأكيد الحساب', textDirection: TextDirection.rtl),
    content: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 400,
        maxHeight: MediaQuery.sizeOf(context).height * 0.65,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              order.label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...order.items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item.displayName} × ${item.quantity} • ${item.unitPrice.toStringAsFixed(2)} ج.م للواحد${item.discountPerUnit > 0 ? ' • خصم ${item.discountPerUnit.toStringAsFixed(2)} للوحدة' : ''}',
                      ),
                    ),
                    Text('${item.total.toStringAsFixed(2)} ج.م'),
                  ],
                ),
              ),
            ),
            for (final session in order.roomSessions)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${session.mode == 'multi' ? 'Multi' : 'Single'} • ${_formatDuration(session.durationMinutesAt(session.endedAt ?? DateTime.now()))} • ${_formatTimestamp(session.startedAt)} إلى ${_formatTimestamp(session.endedAt ?? DateTime.now())} • ${session.hourlyRate.toStringAsFixed(2)} ج.م/ساعة${session.discount > 0 ? ' • خصم ${session.discount.toStringAsFixed(2)} ج.م' : ''}',
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (session.discount > 0)
                          Text(
                            'خصم ${session.discount.toStringAsFixed(2)} ج.م',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.redAccent,
                            ),
                          ),
                        Text(
                          '${session.chargeAt(session.endedAt ?? DateTime.now()).toStringAsFixed(2)} ج.م',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const Divider(),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'الإجمالي',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '${order.total.toStringAsFixed(2)} ج.م',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('رجوع'),
      ),
      FilledButton.icon(
        onPressed: () => Navigator.pop(context, true),
        icon: const Icon(Icons.payments_outlined),
        label: const Text('تأكيد الدفع'),
      ),
    ],
  );
}

String _formatDuration(int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return '${hours.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
}

String _formatTimestamp(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';
