import 'package:flutter/material.dart';

Future<DateTime?> chooseCafeRoomStartTime(
  BuildContext context, {
  DateTime? initialDateTime,
}) async {
  final initial = initialDateTime ?? DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2000),
    lastDate: DateTime.now(),
    helpText: 'اختر تاريخ بداية الجلسة',
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
    helpText: 'اختر وقت بداية الجلسة',
  );
  if (time == null) return null;
  final selected = DateTime(
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
  );
  if (selected.isAfter(DateTime.now())) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('وقت بداية الجلسة لا يمكن أن يكون بالمستقبل'),
        ),
      );
    }
    return null;
  }
  return selected;
}

class CafeRoomBooking {
  const CafeRoomBooking({
    required this.mode,
    required this.hourlyRate,
    required this.startedAt,
  });

  final String mode;
  final double hourlyRate;
  final DateTime startedAt;
}

Future<CafeRoomBooking?> showCafeRoomBookingDialog(
  BuildContext context, {
  required int roomNumber,
  required Map<String, double> hourlyRates,
}) => showDialog<CafeRoomBooking>(
  context: context,
  builder: (_) =>
      CafeRoomBookingDialog(roomNumber: roomNumber, hourlyRates: hourlyRates),
);

class CafeRoomBookingDialog extends StatefulWidget {
  const CafeRoomBookingDialog({
    super.key,
    required this.roomNumber,
    required this.hourlyRates,
  });

  final int roomNumber;
  final Map<String, double> hourlyRates;

  @override
  State<CafeRoomBookingDialog> createState() => _CafeRoomBookingDialogState();
}

class _CafeRoomBookingDialogState extends State<CafeRoomBookingDialog> {
  String _mode = 'single';
  DateTime _startedAt = DateTime.now();

  double get _hourlyRate =>
      widget.hourlyRates['room_${widget.roomNumber}_$_mode'] ?? 40;

  Future<void> _chooseStartTime() async {
    final selected = await chooseCafeRoomStartTime(
      context,
      initialDateTime: _startedAt,
    );
    if (selected != null && mounted) setState(() => _startedAt = selected);
  }

  void _start() => Navigator.pop(
    context,
    CafeRoomBooking(
      mode: _mode,
      hourlyRate: _hourlyRate,
      startedAt: _startedAt,
    ),
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('جلسة أوضة البلايستيشن ${widget.roomNumber}'),
    content: SizedBox(
      width: 380,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'single',
                label: Text('Single'),
                icon: Icon(Icons.person_outline),
              ),
              ButtonSegment(
                value: 'multi',
                label: Text('Multi'),
                icon: Icon(Icons.group_outlined),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (selection) =>
                setState(() => _mode = selection.first),
          ),
          const SizedBox(height: 16),
          Text(
            'السعر: ${_hourlyRate.toStringAsFixed(2)} جنيه لكل ساعة',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _chooseStartTime,
            icon: const Icon(Icons.schedule),
            label: Text('بداية الجلسة: ${_formatDateTime(_startedAt)}'),
          ),
          const SizedBox(height: 6),
          const Text(
            'تقدر تعدّل تاريخ ووقت البداية لو نسيت تسجيل الجلسة وقتها. كل الفترات هتتضاف لنفس الفاتورة.',
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      FilledButton.icon(
        onPressed: _start,
        icon: const Icon(Icons.play_arrow),
        label: const Text('بدء الجلسة'),
      ),
    ],
  );
}

String _formatDateTime(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
