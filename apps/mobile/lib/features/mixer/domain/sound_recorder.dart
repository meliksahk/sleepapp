/// **Kendi kaydın** (F3) — mikrofonu bir DOSYAYA yazan port.
///
/// ## Uyku takibindeki mikrofon yolundan neden ayrı
///
/// `RecordMicSource` bilerek dosyaya yazMIYOR: gece boyunca ham ses diske
/// düşerse hem gigabaytlar birikir hem de "mikrofon verisi cihazda kalır ve
/// TUTULMAZ" ilkesi (CLAUDE.md §6) delinir. Orada akış dB'ye indirgenip atılır.
///
/// Burada niyet TAM TERSİ ve kullanıcının kendi kararı: "şu anki sesi kaydet,
/// kütüphaneme koy". Dosya kullanıcınındır, cihazda kalır, **sunucuya
/// gönderilmez** (UGC ertelendi — paylaşma yok, yalnızca kendi kaydın).
/// İki niyeti tek sınıfta birleştirmek, birinin kuralını diğerine sızdırırdı.
library;

/// Kaydın azami süresi.
///
/// **Neden sınır var:** kayıt ekranı açık unutulursa dosya sessizce büyür ve
/// 150 MB'lık kütüphane tavanını tek başına yer. 5 dakika, "bir yerin sesini
/// yakalamak" için fazlasıyla yeterli (mikserde zaten döngülenir) ve AAC'de
/// ~5 MB eder.
const Duration kMaxRecordingDuration = Duration(minutes: 5);

/// Mikrofonu dosyaya kaydeden port. Uygulaması `data/record_sound_recorder.dart`.
abstract class SoundRecorder {
  /// Kullanıcı mikrofon iznini verdi mi (istemez, yalnızca SORAR).
  Future<bool> hasPermission();

  /// İzin ister; kullanıcı reddederse false.
  Future<bool> requestPermission();

  /// [path]'e kaydetmeye başlar. Dosya kütüphane dizinindedir (`.part` adıyla).
  Future<void> start(String path);

  /// Kaydı bitirir. Dönen yol yazılan dosyadır; başarısızsa null.
  Future<String?> stop();

  /// Kaydı iptal eder ve yarım dosyayı siler.
  Future<void> cancel();

  Future<void> dispose();
}
