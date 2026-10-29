class CafeRoomSession {
  const CafeRoomSession({
    required this.id,
    required this.mode,
    required this.hourlyRate,
    required this.startedAt,
    this.endedAt,
    this.legacyFixedCharge,
    this.discount = 0,
  });

  final String id;
  final String mode;
  final double hourlyRate;
  final DateTime startedAt;
  final DateTime? endedAt;

  /// Keeps rooms booked with the old fixed price intact during migration.
  final double? legacyFixedCharge;
  final double discount;

  bool get isActive => endedAt == null;

  Duration durationAt(DateTime time) {
    final duration = (endedAt ?? time).difference(startedAt);
    return duration.isNegative ? Duration.zero : duration;
  }

  int durationMinutesAt(DateTime time) => durationAt(time).inSeconds ~/ 60;

  double chargeAt(DateTime time) {
    if (legacyFixedCharge != null) {
      return (legacyFixedCharge! - discount).clamp(0, double.infinity);
    }
    final seconds = durationAt(time).inSeconds.clamp(0, 1 << 31).toDouble();
    final gross = (hourlyRate * seconds / 3600 * 100).roundToDouble() / 100;
    return (gross - discount).clamp(0, double.infinity);
  }

  CafeRoomSession copyWith({DateTime? endedAt, double? discount}) =>
      CafeRoomSession(
        id: id,
        mode: mode,
        hourlyRate: hourlyRate,
        startedAt: startedAt,
        endedAt: endedAt ?? this.endedAt,
        legacyFixedCharge: legacyFixedCharge,
        discount: discount ?? this.discount,
      );
}
