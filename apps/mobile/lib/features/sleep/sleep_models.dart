// Uyku modelleri (docs/04). Kimlik doğrulamalı /v1/sleep uçları.
// Üretilen Dart client (B-3) gelince bu interim modeller değişecek.

class SleepSession {
  const SleepSession({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.nightDate,
    required this.durationMinutes,
    required this.movementEvents,
    required this.soundEvents,
  });

  final String id;
  final String startedAt;
  final String endedAt;
  final String nightDate;
  final int durationMinutes;
  final int movementEvents;
  final int soundEvents;

  /// Süreyi "7h 42m" / "45m" biçiminde döner.
  String get durationText {
    final h = durationMinutes ~/ 60;
    final m = durationMinutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  factory SleepSession.fromJson(Map<String, dynamic> json) => SleepSession(
        id: json['id'] as String,
        startedAt: json['startedAt'] as String,
        endedAt: json['endedAt'] as String,
        nightDate: json['nightDate'] as String,
        durationMinutes: json['durationMinutes'] as int,
        movementEvents: json['movementEvents'] as int,
        soundEvents: json['soundEvents'] as int,
      );
}

class NightReport {
  const NightReport({
    required this.nightDate,
    required this.sessionCount,
    required this.totalDurationMinutes,
    required this.movementEvents,
    required this.soundEvents,
    required this.calmScore,
  });

  final String nightDate;
  final int sessionCount;
  final int totalDurationMinutes;
  final int movementEvents;
  final int soundEvents;
  final int calmScore;

  factory NightReport.fromJson(Map<String, dynamic> json) => NightReport(
        nightDate: json['nightDate'] as String,
        sessionCount: json['sessionCount'] as int,
        totalDurationMinutes: json['totalDurationMinutes'] as int,
        movementEvents: json['movementEvents'] as int,
        soundEvents: json['soundEvents'] as int,
        calmScore: json['calmScore'] as int,
      );
}

class StreakStats {
  const StreakStats({
    required this.current,
    required this.longest,
    required this.totalNights,
  });

  final int current;
  final int longest;
  final int totalNights;

  factory StreakStats.fromJson(Map<String, dynamic> json) => StreakStats(
        current: json['current'] as int,
        longest: json['longest'] as int,
        totalNights: json['totalNights'] as int,
      );
}
