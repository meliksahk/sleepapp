// Uyku modelleri (docs/04). Kimlik doğrulamalı /v1/sleep uçları.
// Üretilen Dart client (B-3) gelince bu interim modeller değişecek.

/// Dakikayı "7h 42m" / "45m" / "0m" biçiminde döner (paylaşılan formatlayıcı).
String formatMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

/// Uyku istatistikleri (GET /v1/sleep/stats).
class SleepStats {
  const SleepStats({
    required this.nights,
    required this.totalDurationMinutes,
    required this.averageDurationMinutes,
  });

  final int nights;
  final int totalDurationMinutes;
  final int averageDurationMinutes;

  factory SleepStats.fromJson(Map<String, dynamic> json) => SleepStats(
    nights: json['nights'] as int,
    totalDurationMinutes: json['totalDurationMinutes'] as int,
    averageDurationMinutes: json['averageDurationMinutes'] as int,
  );
}

/// Bir gecenin trend kovası (GET /v1/sleep/trend içindeki bir öğe).
class TrendNight {
  const TrendNight({required this.nightDate, required this.durationMinutes});

  final String nightDate;
  final int durationMinutes;

  factory TrendNight.fromJson(Map<String, dynamic> json) => TrendNight(
    nightDate: json['nightDate'] as String,
    durationMinutes: json['durationMinutes'] as int,
  );
}

/// Son 7 gecenin uyku trendi (GET /v1/sleep/trend). Geceler eskiden yeniye.
class WeeklyTrend {
  const WeeklyTrend({
    required this.nights,
    required this.averageDurationMinutes,
    required this.nightsWithData,
  });

  final List<TrendNight> nights;
  final int averageDurationMinutes;
  final int nightsWithData;

  factory WeeklyTrend.fromJson(Map<String, dynamic> json) => WeeklyTrend(
    nights: (json['nights'] as List<dynamic>)
        .map((e) => TrendNight.fromJson(e as Map<String, dynamic>))
        .toList(),
    averageDurationMinutes: json['averageDurationMinutes'] as int,
    nightsWithData: json['nightsWithData'] as int,
  );
}

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
  String get durationText => formatMinutes(durationMinutes);

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

/// Gece raporu paylaşım kartı (GET /v1/sharing/report?night=). Viral kanca #2.
class NightReportShare {
  const NightReportShare({
    required this.nightDate,
    required this.title,
    required this.subtitle,
    required this.durationText,
    required this.calmScore,
    required this.webUrl,
    required this.deepLink,
  });

  final String nightDate;
  final String title;
  final String subtitle;
  final String durationText;
  final int calmScore;
  final String webUrl;
  final String deepLink;

  factory NightReportShare.fromJson(Map<String, dynamic> json) =>
      NightReportShare(
        nightDate: json['nightDate'] as String,
        title: json['title'] as String,
        subtitle: json['subtitle'] as String,
        durationText: json['durationText'] as String,
        calmScore: json['calmScore'] as int,
        webUrl: json['webUrl'] as String,
        deepLink: json['deepLink'] as String,
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
