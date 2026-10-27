import 'package:flutter/material.dart';

class CafeRoomBooking {
  const CafeRoomBooking({required this.mode, required this.hourlyRate});

  final String mode;
  final double hourlyRate;
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

  double get _hourlyRate =>
      widget.hourlyRates['room_${widget.roomNumber}_$_mode'] ?? 40;

  void _start() => Navigator.pop(
    context,
    CafeRoomBooking(mode: _mode, hourlyRate: _hourlyRate),
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
          const SizedBox(height: 6),
          const Text(
            'يبدأ حساب الوقت الآن. تقدر تغيّر بين Single وMulti أثناء الجلسة، وكل فترة هتتضاف لنفس الفاتورة.',
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
