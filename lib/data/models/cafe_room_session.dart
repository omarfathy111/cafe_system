class CafeRoomSession {
  const CafeRoomSession({
    required this.id,
    required this.mode,
    required this.hourlyRate,
    required this.startedAt,
    this.endedAt,
    this.legacyFixedCharge,
  });

  final String id;
  final String mode;
  final double hourlyRate;
  final DateTime startedAt;
  final DateTime? endedAt;

  /// Keeps rooms booked with the old fixed price intact during migration.
  final double? legacyFixedCharge;

  bool get isActive => endedAt == null;

  Duration durationAt(DateTime time) {
    final duration = (endedAt ?? time).difference(startedAt);
    return duration.isNegative ? Duration.zero : duration;
  }

  int durationMinutesAt(DateTime time) => durationAt(time).inSeconds ~/ 60;

  double chargeAt(DateTime time) {
    if (legacyFixedCharge != null) return legacyFixedCharge!;
    final seconds = durationAt(time).inSeconds.clamp(0, 1 << 31).toDouble();
    return (hourlyRate * seconds / 3600 * 100).roundToDouble() / 100;
  }

  CafeRoomSession copyWith({DateTime? endedAt}) => CafeRoomSession(
    id: id,
    mode: mode,
    hourlyRate: hourlyRate,
    startedAt: startedAt,
    endedAt: endedAt ?? this.endedAt,
    legacyFixedCharge: legacyFixedCharge,
  );
}
