/// Kullanıcının KENDİ telefonundan getirdiği bir ses — NOCTA kütüphanesinin değil.
///
/// ## Neden sunucudaki `AudioAsset`'ten AYRI bir tip
///
/// İkisini tek tipte birleştirmek cazip ama yanlış olurdu: `AudioAsset` sunucudaki
/// bir kaydın görüntüsüdür (presigned URL'i vardır, süresi dolar, `license` alanı
/// taşır, silinebilir). Bu ise TAMAMEN cihazda yaşar, ağ görmez, lisansı bizi
/// ilgilendirmez ve yalnızca kullanıcı silerse silinir. Tek tipte toplamak, her
/// alanın "hangi durumda dolu" sorusunu her kullanım yerine dağıtırdı.
///
/// **Saf Dart:** bu dosya Flutter ve `dart:io` import ETMEZ (CLAUDE.md §3.1).
library;

/// Şu anki kayıt şeması. Tek bir kaydın çözümü buna bakar; dosyanın tamamının
/// şeması ayrıca `index.json` kökünde durur (iki katlı sürümleme — bkz.
/// `LocalSoundStore`).
const int kLocalSoundSchema = 1;

/// Diske yazılan bir ithal ses kaydı.
class LocalSound {
  const LocalSound({
    required this.id,
    required this.title,
    required this.fileName,
    required this.sizeBytes,
    required this.importedAt,
    this.schema = kLocalSoundSchema,
  });

  /// `local-<16hex>`. **Önek pazarlıksız:** `MixerController` sentez ve dosya
  /// katmanlarını TEK bir `gains` haritasında tutuyor ve `MixPlayer.setLayerGain`
  /// id ile eşleşiyor — çakışan id, sürgünün YANLIŞ katmanı oynatması demek.
  /// Sunucu id'leri uuid olduğu için bu önekle asla çakışmaz.
  final String id;

  /// Kullanıcıya gösterilen ad. **i18n'e girmez** — bu bir içerik adıdır
  /// (kullanıcının kendi dosya adı), arayüz metni değil.
  final String title;

  /// Dizin İÇİNDEKİ dosya adı — **MUTLAK YOL DEĞİL.**
  ///
  /// Bu ayrım tek satırlık ama tüm kütüphaneyi kurtarıyor: iOS'ta uygulama
  /// konteyner UUID'si güncellemede/yeniden kurulumda DEĞİŞİR. Mutlak yol
  /// saklasaydık, bir güncellemeden sonra kaydedilmiş her yol var olmayan bir
  /// dizini gösterirdi ve kullanıcının TÜM kütüphanesi tek seferde "dosya yok"
  /// durumuna düşerdi. Mutlak yol her okumada güncel dizinle birleştirilir.
  /// `local_sound_store_test.dart` kaydedilen hiçbir ada ayraç girmediğini kilitler.
  final String fileName;

  final int sizeBytes;
  final DateTime importedAt;

  /// Bu KAYDIN şeması. Dosyanın tamamının şemasından ayrı: bir kayıt kırıldığında
  /// diğerlerini feda etmemek için.
  final int schema;

  Map<String, Object?> toJson() => <String, Object?>{
        'schema': schema,
        'id': id,
        'title': title,
        'fileName': fileName,
        'sizeBytes': sizeBytes,
        'importedAt': importedAt.toUtc().toIso8601String(),
      };

  /// Bozuk/eksik kayıtta **ATMAZ, null döner.**
  ///
  /// Per-kayıt tolerans burada başlar: `LocalSoundStore` bu null'ı görüp yalnızca
  /// o kaydı atlar, kalanı korur. `LocalArchetypeStore`'un "hepsini at" politikası
  /// buraya KOPYALANMADI ve bu bilinçli: arketip testini kullanıcı yeniden çözebilir,
  /// ama 30 dosyayı tek tek yeniden seçmek istemez.
  static LocalSound? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final title = raw['title'];
    final fileName = raw['fileName'];
    final sizeBytes = raw['sizeBytes'];
    final importedAt = raw['importedAt'];
    final schema = raw['schema'];

    if (id is! String || id.isEmpty) return null;
    if (title is! String) return null;
    if (fileName is! String || fileName.isEmpty) return null;
    // Ayraç taşıyan bir ad, mutlak yol saklama regresyonunun ta kendisi olurdu;
    // ayrıca '../' ile dizin dışına çıkma denemesini de burada keseriz.
    if (fileName.contains('/') || fileName.contains(r'\')) return null;
    if (sizeBytes is! int || sizeBytes < 0) return null;
    if (importedAt is! String) return null;
    final parsed = DateTime.tryParse(importedAt);
    if (parsed == null) return null;
    if (schema is! int || schema > kLocalSoundSchema) return null;

    return LocalSound(
      id: id,
      title: title,
      fileName: fileName,
      sizeBytes: sizeBytes,
      importedAt: parsed,
      schema: schema,
    );
  }
}

/// İthalin NEDEN olmadığı. Her değer kullanıcıya AYRI bir metin gösterir —
/// hepsini tek "eklenemedi" mesajına düşürmek, kullanıcının çözebileceği bir
/// sorunu (dosya çok büyük) çözemeyeceği bir sorundan (biçim desteklenmiyor)
/// ayırt edilemez kılardı.
enum LocalSoundImportFailure {
  /// Kullanıcı seçiciyi kapattı. **Hata DEĞİL** — ekranda hiçbir şey gösterilmez.
  cancelled,
  tooLarge,
  libraryFull,
  notAudio,
  noSpace,
  sourceGone,
  pickerFailed,
  tooManyLayers,
  unknown,
}

/// İthal sonucu — **kısmi durum temsil edilemez.**
///
/// `bool` + `LocalSound?` ikilisi "başarılı ama ses yok" gibi imkânsız bir hâli
/// tip seviyesinde mümkün kılardı; sealed sınıf onu derleyicide keser.
sealed class LocalSoundImportResult {
  const LocalSoundImportResult();
}

class LocalSoundImported extends LocalSoundImportResult {
  const LocalSoundImported(this.sound);
  final LocalSound sound;
}

class LocalSoundImportRejected extends LocalSoundImportResult {
  const LocalSoundImportRejected(
    this.reason, {
    this.sizeBytes,
    this.usedBytes,
  });

  final LocalSoundImportFailure reason;

  /// `tooLarge` için dosyanın boyutu, `libraryFull` için kullanılan toplam —
  /// kullanıcıya "sınır 50 MB" demek yetmez, "bu dosya 78 MB" demek gerekir.
  final int? sizeBytes;
  final int? usedBytes;
}
