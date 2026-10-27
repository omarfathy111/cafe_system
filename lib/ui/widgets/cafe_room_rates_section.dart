import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

class CafeRoomRatesSection extends StatelessWidget {
  const CafeRoomRatesSection({
    super.key,
    required this.rates,
    required this.onSave,
  });

  final Map<String, double> rates;
  final Future<void> Function(int room, String mode, double rate) onSave;

  Future<void> _editRate(BuildContext context, int room, String mode) async {
    final key = 'room_${room}_$mode';
    final modeLabel = mode == 'multi' ? 'Multi' : 'Single';
    final controller = TextEditingController(
      text: (rates[key] ?? 40).toStringAsFixed(2),
    );
    final rate = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('سعر $modeLabel لأوضة $room'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'السعر لكل ساعة بالجنيه',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              if (value == null || value <= 0) return;
              Navigator.pop(dialogContext, value);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (rate != null) await onSave(room, mode, rate);
  }

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'أسعار أوض البلايستيشن لكل ساعة',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          for (var room = 1; room <= 2; room++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('أوضة $room'),
              subtitle: Text(
                'Single: ${(rates['room_${room}_single'] ?? 40).toStringAsFixed(2)} ج.م/ساعة  •  '
                'Multi: ${(rates['room_${room}_multi'] ?? 40).toStringAsFixed(2)} ج.م/ساعة',
              ),
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    tooltip: 'تعديل سعر Single',
                    onPressed: () => _editRate(context, room, 'single'),
                    icon: const Icon(Icons.person_outline),
                  ),
                  IconButton(
                    tooltip: 'تعديل سعر Multi',
                    onPressed: () => _editRate(context, room, 'multi'),
                    icon: const Icon(Icons.group_outlined),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
