import 'package:cafe_system/features/pos/data/cafe_order_item.dart';
import 'package:cafe_system/features/pos/data/cafe_room_session.dart';

export 'package:cafe_system/features/pos/data/cafe_order_item.dart';
export 'package:cafe_system/features/pos/data/cafe_room_session.dart';

class CafeOrder {
  CafeOrder({
    required this.id,
    required this.label,
    this.tableNumber,
    this.roomNumber,
    this.isTakeaway = false,
    this.note = '',
    List<CafeOrderItem>? items,
    List<CafeRoomSession>? roomSessions,
    DateTime? createdAt,
  }) : items = items ?? [],
       roomSessions = roomSessions ?? [],
       createdAt = createdAt ?? DateTime.now();

  final String id;
  final String label;
  final int? tableNumber;
  final int? roomNumber;
  final bool isTakeaway;
  final String note;
  final List<CafeOrderItem> items;
  final List<CafeRoomSession> roomSessions;
  final DateTime createdAt;

  bool get hasRoomSession => roomNumber != null && roomSessions.isNotEmpty;

  CafeRoomSession? get activeRoomSession =>
      roomSessions.where((session) => session.isActive).firstOrNull;

  DateTime? get roomStartedAt =>
      roomSessions.isEmpty ? null : roomSessions.first.startedAt;

  DateTime? get roomEndedAt =>
      activeRoomSession == null && roomSessions.isNotEmpty
      ? roomSessions.last.endedAt
      : null;

  String? get roomPricingMode =>
      activeRoomSession?.mode ??
      (roomSessions.isEmpty ? null : roomSessions.last.mode);

  double? get roomPrice =>
      activeRoomSession?.hourlyRate ??
      (roomSessions.isEmpty ? null : roomSessions.last.hourlyRate);

  Duration roomDurationAt(DateTime time) => Duration(
    seconds: roomSessions.fold<int>(
      0,
      (total, session) => total + session.durationAt(time).inSeconds,
    ),
  );

  int roomDurationMinutesAt(DateTime time) =>
      roomDurationAt(time).inSeconds ~/ 60;

  double roomChargeAt(DateTime time) => roomSessions.fold<double>(
    0,
    (total, session) => total + session.chargeAt(time),
  );

  double get roomCharge => roomChargeAt(DateTime.now());
  double get total =>
      items.fold<double>(0, (sum, item) => sum + item.total) + roomCharge;

  CafeOrder copyWith({
    String? label,
    List<CafeOrderItem>? items,
    List<CafeRoomSession>? roomSessions,
    String? note,
  }) => CafeOrder(
    id: id,
    label: label ?? this.label,
    tableNumber: tableNumber,
    roomNumber: roomNumber,
    isTakeaway: isTakeaway,
    note: note ?? this.note,
    items: items ?? this.items,
    roomSessions: roomSessions ?? this.roomSessions,
    createdAt: createdAt,
  );
}
