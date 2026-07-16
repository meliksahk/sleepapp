import 'event_detector.dart';

/// Olayın hangi kovaya yazılacağı. API iki kova sunuyor (`movementEvents`,
/// `soundEvents`); docs/04 §85 "basit olay sınıflandırması (hareket/horlama/gürültü)"
/// diyor → horlama ve gürültü ikisi de "ses" kovasına düşer.
enum AcousticEventKind { movement, sound }

/// **AYRIM SÜREYE DAYANIR ve DOĞRULANMADI.**
///
/// Gerekçe: yatakta dönmek/hışırdamak KISA bir olaydır (yarım saniye); horlama,
/// köpek, trafik daha UZUN sürer. Bu, docs/04 §85'in kastettiği "basit
/// sınıflandırma"nın en savunulabilir hâli — ama mikrofonla hareketi sesten
/// ayırmanın DOĞRU yolu değil, sadece ucuz olanı.
///
/// **NE İDDİA ETMİYORUZ:** bu sayılar "kaç kez döndünüz"ün ölçümü değildir. Gerçek
/// gece kayıtlarıyla (docs/04 §120 fixture'ları) ayarlanana kadar ürün metni de
/// bunları kesin gerçek gibi sunmamalı (bkz. DECISIONS_NEEDED D-10).
const int defaultMaxMovementFrames = 20; // ~1 sn (@50 ms/çerçeve)

AcousticEventKind classifyEvent(
  AcousticEvent event, {
  int maxMovementFrames = defaultMaxMovementFrames,
}) =>
    event.durationFrames <= maxMovementFrames
        ? AcousticEventKind.movement
        : AcousticEventKind.sound;

/// API'ye gönderilecek oturum taslağı (`RecordSleepSessionDto` ile birebir).
///
/// **HAM SES YOK, ZARF YOK, OLAY DETAYI YOK** — yalnızca sayılar ve zaman
/// (CLAUDE.md §6: "sunucuya yalnızca türetilmiş metrikler gider"). Bu sınıfın
/// alanları o sözün somut hâlidir: buradan öteye ne geçerse gizlilik iddiamızı
/// zayıflatır.
class SleepSessionDraft {
  const SleepSessionDraft({
    required this.startedAt,
    required this.endedAt,
    required this.movementEvents,
    required this.soundEvents,
  });

  final DateTime startedAt;
  final DateTime endedAt;
  final int movementEvents;
  final int soundEvents;

  Duration get duration => endedAt.difference(startedAt);

  /// API gövdesi. Zaman **UTC + ISO 8601** (CLAUDE.md §4): cihaz yerel saatiyle
  /// göndermek, sunucudaki "gece" gruplamasını (06:00 sınırı) sessizce kaydırırdı.
  Map<String, Object> toJson() => {
        'startedAt': startedAt.toUtc().toIso8601String(),
        'endedAt': endedAt.toUtc().toIso8601String(),
        'movementEvents': movementEvents,
        'soundEvents': soundEvents,
      };
}

/// Dedektör çıktısı + oturum zamanı → API'nin beklediği taslak.
///
/// [startedAt]/[endedAt] duvar saati; olaylar çerçeve indeksiyle gelir. İkisini
/// burada birleştiriyoruz çünkü dedektör saati, alarm da çerçeveyi bilmemeli.
SleepSessionDraft buildSleepSession({
  required List<AcousticEvent> events,
  required DateTime startedAt,
  required DateTime endedAt,
  int maxMovementFrames = defaultMaxMovementFrames,
}) {
  assert(!endedAt.isBefore(startedAt), 'Oturum bitişi başlangıçtan önce olamaz');

  var movement = 0;
  var sound = 0;
  for (final e in events) {
    if (classifyEvent(e, maxMovementFrames: maxMovementFrames) == AcousticEventKind.movement) {
      movement++;
    } else {
      sound++;
    }
  }

  return SleepSessionDraft(
    startedAt: startedAt,
    endedAt: endedAt,
    movementEvents: movement,
    soundEvents: sound,
  );
}
