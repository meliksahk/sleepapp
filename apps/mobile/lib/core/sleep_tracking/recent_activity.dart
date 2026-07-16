import 'event_detector.dart';

/// "Son N dakikada akustik aktivite var mı?" — [AcousticEventDetector] çıktısını
/// [SmartAlarm]'ın anlayacağı tek bir bool'a indirger.
///
/// **NEDEN AYRI DOSYA:** dedektör çerçeve indeksiyle, alarm ise duvar saatiyle
/// çalışır. Bu çeviriyi ikisinden birinin içine gömmek, o sınıfı diğerinin
/// zaman kavramına bağlardı; ikisi de artık kendi biriminde saf kalıyor.
///
/// **SEZGİSEL (dürüstlük):** "yakın zamanda ses çıkardı = hafif uyku" varsayımı
/// uyku evrelemesiyle DOĞRULANMADI. Kategori standardı budur ama iddia
/// "hareketlendiğinde uyandırırız" ile sınırlı kalmalı (CLAUDE.md §1.1).
bool hasRecentActivity({
  required List<AcousticEvent> events,
  required int currentFrame,
  required Duration lookback,
  required Duration frameDuration,
}) {
  assert(frameDuration > Duration.zero);
  if (events.isEmpty) return false;

  final lookbackFrames = lookback.inMicroseconds ~/ frameDuration.inMicroseconds;
  // 0 çerçevelik pencere hiçbir olayı görmez; en az 1 çerçeve bakılır — aksi halde
  // çok küçük bir lookback sessizce "hep false" olurdu.
  final threshold = currentFrame - (lookbackFrames < 1 ? 1 : lookbackFrames);

  // Olay penceresi KESİŞİYORSA sayılır: süregelen uzun bir olay (horlama) geçmişte
  // başlamış olabilir; yalnızca başlangıcına baksaydık "şu an ses var" durumunu
  // kaçırırdık.
  for (final e in events) {
    final endFrame = e.startFrame + e.durationFrames;
    if (endFrame >= threshold) return true;
  }
  return false;
}
