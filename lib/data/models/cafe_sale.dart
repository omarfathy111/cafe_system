import 'cafe_order.dart';

class CafeSale {
  CafeSale({
    required this.id,
    required this.label,
    required this.total,
    required this.time,
    required this.items,
    this.roomSessions = const [],
    this.roomCharge = 0,
    this.roomMinutes = 0,
    this.roomStartedAt,
    this.roomEndedAt,
    this.note = '',
  });
  final int id;
  final String label;
  final double total;
  final DateTime time;
  final Map<String, int> items;
  final List<CafeRoomSession> roomSessions;
  final double roomCharge;
  final int roomMinutes;
  final DateTime? roomStartedAt;
  final DateTime? roomEndedAt;
  final String note;

  factory CafeSale.fromOrder({
    required int id,
    required CafeOrder order,
    required DateTime time,
    DateTime? roomSessionEndedAt,
  }) {
    final summary = <String, int>{};
    for (final item in order.items) {
      final name = item.discountPerUnit > 0
          ? '${item.displayName} (خصم ${item.discountPerUnit.toStringAsFixed(2)} للوحدة)'
          : item.displayName;
      summary.update(
        name,
        (quantity) => quantity + item.quantity,
        ifAbsent: () => item.quantity,
      );
    }
    final sessionEnd = roomSessionEndedAt ?? time;
    final roomMinutes = order.roomDurationMinutesAt(sessionEnd);
    final roomCharge = order.roomChargeAt(sessionEnd);
    for (final session in order.roomSessions) {
      final segmentEnd = session.endedAt ?? sessionEnd;
      summary.update(
        'بلايستيشن ${session.mode == 'multi' ? 'Multi' : 'Single'} • ${_formatTimestamp(session.startedAt)}-${_formatTimestamp(segmentEnd)} • ${_formatDuration(session.durationMinutesAt(segmentEnd))}${session.discount > 0 ? ' • خصم ${session.discount.toStringAsFixed(2)} ج.م' : ''} • ${session.chargeAt(segmentEnd).toStringAsFixed(2)} ج.م',
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    return CafeSale(
      id: id,
      label: order.label,
      total: order.total,
      time: time,
      items: summary,
      roomSessions: order.roomSessions,
      roomCharge: roomCharge,
      roomMinutes: roomMinutes,
      roomStartedAt: order.roomStartedAt,
      roomEndedAt: order.roomEndedAt ?? roomSessionEndedAt,
      note: order.note,
    );
  }
}

String _formatDuration(int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return '${hours.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
}

String _formatTimestamp(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';
