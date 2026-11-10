import 'package:cafe_system/core/utils/app_constants.dart';
import 'package:flutter/material.dart';

class CafeRoomRatesSection extends StatelessWidget {
  const CafeRoomRatesSection({
    super.key,
    required this.rates,
    required this.onSave,
    this.roomNames = const {},
    this.onSaveRoomName,
  });

  final Map<String, double> rates;
  final Future<void> Function(int room, String mode, double rate) onSave;
  final Map<String, String> roomNames;
  final Future<void> Function(int room, String name)? onSaveRoomName;

  Future<void> _editName(BuildContext context, int room) async {
    final controller = TextEditingController(
      text: roomNames['room_$room'] ?? '',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('اسم أوضة البلايستيشن $room'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'الاسم الجديد'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null) await onSaveRoomName?.call(room, name);
  }

  Future<void> _editRate(BuildContext context, int room, String mode) async {
    final key = 'room_${room}_$mode';
    final modeLabel = mode == 'multi' ? 'Multi' : 'Single';
    final controller = TextEditingController(
      text: (rates[key] ?? 40).toStringAsFixed(2),
    );
    final rate = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'سعر $modeLabel لـ ${roomNames['room_$room'] ?? 'أوضة $room'}',
        ),
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
              if (value == null || !value.isFinite || value <= 0) return;
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
              title: Text(roomNames['room_$room'] ?? 'أوضة $room'),
              subtitle: Text(
                'Single: ${(rates['room_${room}_single'] ?? 40).toStringAsFixed(2)} ج.م/ساعة  •  '
                'Multi: ${(rates['room_${room}_multi'] ?? 40).toStringAsFixed(2)} ج.م/ساعة',
              ),
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    tooltip: 'تعديل اسم الأوضة',
                    onPressed: onSaveRoomName == null
                        ? null
                        : () => _editName(context, room),
                    icon: const Icon(Icons.edit_outlined),
                  ),
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
