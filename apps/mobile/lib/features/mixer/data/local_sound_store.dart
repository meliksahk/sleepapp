import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;

import '../domain/local_sound.dart';
import '../domain/local_sound_library.dart';
import 'sound_picker.dart' show kSupportedAudioExtensions;

/// İthal edilen seslerin MANİFESTİ — `nocta_sounds/index.json`.
///
/// ## Neden shared_preferences DEĞİL
///
/// Üç sebep, sonuncusu belirleyici:
/// 1. prefs Android'de ana thread'de senkron XML yazar.
/// 2. `SharedPreferences.getInstance` süreç başına TEK singleton ve kendi bellek
///    içi cache'ini tutar. Bu yüzden prefs üstüne kurulu bir "yeniden açılış"
///    testi aslında yeniden açılışı test ETMEZ (iki store aynı cache'i paylaşır,
///    deserializasyon hiç koşmaz). Bu tuzağa düşmek istemedik.
/// 3. **En önemlisi:** ses dosyaları dosya sisteminde yaşıyor. Manifest başka bir
///    depoda olsaydı ikisi bağımsız bozulabilir ve aşağıdaki "diskten yeniden
///    inşa" kurtarması İMKÂNSIZ olurdu. Manifest, baytların yanında durmalı.
///
/// ## Bozuk veri: üç ayrı hâl, üç ayrı cevap
///
/// Bu ayrım bu dosyanın varlık sebebi. Hepsini "boş dön" diye birleştirmek,
/// ardından koşan uzlaştırmanın kullanıcının tüm kütüphanesini yetim ilan edip
/// silmesi demekti.
class LocalSoundStore {
  LocalSoundStore({required this.dir});

  /// Dizin sağlayıcısı **enjekte edilebilir**: testte gerçek bir geçici dizin
  /// verilir. `path_provider`'ın platform kanalı mock'lanmaz — repoda örneği yok
  /// ve gerçek dosya sistemine yazan bir test, bu deponun asıl vaadini (yeniden
  /// açılışta veri duruyor) GERÇEKTEN sınar.
  final Future<Directory> Function() dir;

  static const String indexFileName = 'index.json';

  /// Dosyanın TAMAMININ şeması. Kayıt başına şema ayrıca `LocalSound.schema`'da:
  /// biri kırıldığında diğerini feda etmemek için iki katlı.
  static const int fileSchemaVersion = 1;

  /// Tüm yazmalar bu zincirde SERİLEŞTİRİLİR.
  ///
  /// ⚠️ **Bu koruma "sadeleştirme" adına silinirse hata SESSİZ ve KALICI olur:**
  /// eşzamanlı iki ithalde read-modify-write yarışı yalnızca bir kaydı kaybetmez,
  /// o kaydın DOSYASINI diskte yetim bırakır (kayıt yok, bayt var).
  Future<void> _queue = Future<void>.value();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final completer = _queue.then((_) => action());
    _queue = completer.then((_) {}, onError: (_) {});
    return completer;
  }

  /// Manifesti okur. **Hiçbir dalda dosya SİLMEZ.**
  Future<LocalSoundIndex> read() async {
    final Directory directory;
    final File file;
    try {
      directory = await dir();
      file = File(p.join(directory.path, indexFileName));
      if (!await file.exists()) {
        // Gerçekten boş kütüphane ile diskte kalmış dosyalar farklı: manifest
        // yokken diskte ses varsa (silinmiş index, yeni kurulum) yine inşa ederiz.
        final rebuilt = await _rebuildFromDisk(directory);
        return LocalSoundIndexOk(rebuilt);
      }
    } on FileSystemException catch (e) {
      // GEÇİCİ IO HATASI — izin, kilit, çıkarılmış depolama. Hiçbir şey yeniden
      // adlandırılmaz: aksi hâlde geçici bir okuma hatası HER çağrıda bir
      // `.corrupt` daha üretir ve gerçek bozulmayı gürültüye boğar.
      debugPrint('nocta.localsound: dizin okunamadı: $e');
      return const LocalSoundIndexUnreadable();
    }

    final String raw;
    try {
      raw = await file.readAsString();
    } on FileSystemException catch (e) {
      debugPrint('nocta.localsound: index okunamadı (geçici): $e');
      return const LocalSoundIndexUnreadable();
    }

    Object? decoded;
    var parseFailed = false;
    try {
      decoded = jsonDecode(raw);
    } catch (e) {
      debugPrint('nocta.localsound: index ayrıştırılamadı: $e');
      parseFailed = true;
    }

    if (!parseFailed && decoded is Map) {
      final version = decoded['schemaVersion'];
      final sounds = decoded['sounds'];
      if (version is int && version <= fileSchemaVersion && sounds is List) {
        // TEK KAYIT BOZUK: yalnızca o atlanır, kalan KORUNUR.
        final out = <LocalSound>[];
        var skipped = 0;
        for (final entry in sounds) {
          final parsed = LocalSound.fromJson(entry);
          if (parsed == null) {
            skipped++;
            continue;
          }
          out.add(parsed);
        }
        if (skipped > 0) {
          // Sessiz değil (CLAUDE.md §4) ama yıkıcı da değil.
          debugPrint('nocta.localsound: $skipped bozuk kayıt atlandı');
        }
        return LocalSoundIndexOk(out);
      }
      debugPrint('nocta.localsound: tanınmayan şema/gövde: $version');
    }

    // AYRIŞTIRMA HATASI — burada ve YALNIZCA burada karantina + yeniden inşa.
    return LocalSoundIndexOk(await _quarantineAndRebuild(directory, file));
  }

  /// Bozuk manifesti **silmez**, yeniden adlandırır ve kütüphaneyi DİSKTEN kurar.
  ///
  /// Kopyalama yaklaşımının asıl kazancı burada: dosya sistemi İKİNCİ doğruluk
  /// kaynağıdır. Kullanıcı en fazla ithal sırasını kaybeder, SESLERİNİ kaybetmez.
  Future<List<LocalSound>> _quarantineAndRebuild(Directory dir, File file) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    try {
      await file.rename(p.join(dir.path, '$indexFileName.corrupt-$stamp'));
      debugPrint('nocta.localsound: bozuk index karantinaya alındı ($stamp)');
    } on FileSystemException catch (e) {
      // Yeniden adlandıramadık — yine de yeniden inşa ediyoruz; en kötü ihtimalle
      // bir sonraki yazma bozuk dosyanın üstüne yazar.
      debugPrint('nocta.localsound: karantina başarısız: $e');
    }
    final rebuilt = await _rebuildFromDisk(dir);
    if (rebuilt.isNotEmpty) {
      await _writeUnserialized(dir, rebuilt);
    }
    return rebuilt;
  }

  /// Dizindeki ses dosyalarından kayıt üretir.
  ///
  /// Kimlik dosya ADINDA yaşadığı için (`<16hex>__<slug>.<uzantı>`) kurtarma
  /// anlamlı: kullanıcı `local-1784...` gibi 20 anlamsız satır değil, kendi
  /// verdiği adları görür. Kayıp yalnızca kozmetiktir (sıra, tirelerin boşluğa
  /// dönmesi).
  Future<List<LocalSound>> _rebuildFromDisk(Directory dir) async {
    if (!await dir.exists()) return const <LocalSound>[];
    final out = <LocalSound>[];
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        final decoded = decodeFileName(name);
        if (decoded == null) continue;
        final stat = await entity.stat();
        out.add(LocalSound(
          id: decoded.id,
          title: decoded.title,
          fileName: name,
          sizeBytes: stat.size,
          importedAt: stat.modified,
        ));
      }
    } on FileSystemException catch (e) {
      debugPrint('nocta.localsound: yeniden inşa taraması yarım kaldı: $e');
    }
    out.sort((a, b) => a.importedAt.compareTo(b.importedAt));
    return out;
  }

  Future<void> write(List<LocalSound> sounds) => _serialized(() async {
        await _writeUnserialized(await dir(), sounds);
      });

  /// **ATOMİK:** `.tmp`'ye yazıp rename eder. Doğrudan yazsaydık, yazma
  /// ortasında ölen bir süreç yarım JSON bırakır ve her açılışta karantina
  /// tetiklenirdi.
  Future<void> _writeUnserialized(Directory dir, List<LocalSound> sounds) async {
    if (!await dir.exists()) await dir.create(recursive: true);
    final tmp = File(p.join(dir.path, '$indexFileName.tmp'));
    final payload = jsonEncode(<String, Object?>{
      'schemaVersion': fileSchemaVersion,
      'sounds': <Map<String, Object?>>[for (final s in sounds) s.toJson()],
    });
    await tmp.writeAsString(payload, flush: true);
    await tmp.rename(p.join(dir.path, indexFileName));
  }

  /// Kayıt listesini oku-değiştir-yaz — **serileştirilmiş.**
  Future<void> mutate(
    List<LocalSound> Function(List<LocalSound> current) change,
  ) =>
      _serialized(() async {
        final directory = await dir();
        final index = await read();
        // Okunamayan indeksin üstüne yazmak, kurtarılabilir veriyi ezmek olurdu.
        if (index is! LocalSoundIndexOk) {
          debugPrint('nocta.localsound: index okunamıyor, yazma atlandı');
          return;
        }
        await _writeUnserialized(directory, change(index.sounds));
      });

  // ---------------------------------------------------------------------------
  // Dosya adı sözleşmesi: <16hex>__<slug>.<uzantı>
  //
  // Kullanıcının HAM dosya adı diskte KULLANILMAZ: '../' ile dizin dışına çıkma,
  // ayrılmış karakterler, uzunluk sınırları ve çakışma hepsi buradan girerdi.
  // Adı biz üretiriz — ama sterilize edilmiş slug'ı İÇİNE gömeriz, çünkü kimlik
  // yalnızca manifestte yaşasaydı yukarıdaki yeniden inşa kullanılamaz bir
  // kütüphane üretirdi.
  // ---------------------------------------------------------------------------

  static String buildFileName({
    required String hex,
    required String title,
    required String extension,
  }) =>
      '${hex}__${slugify(title)}.$extension';

  static String slugify(String input) {
    final lower = input.toLowerCase();
    final replaced = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final trimmed = replaced.replaceAll(RegExp(r'^-+|-+$'), '');
    if (trimmed.isEmpty) return 'ses';
    return trimmed.length <= 40 ? trimmed : trimmed.substring(0, 40);
  }

  /// `3f2a9c1b7e0d4a86__night-rain.mp3` → id + başlık. Sözleşmeye uymayan ya da
  /// desteklenmeyen uzantılı dosyalarda **null** (index.json, .part, .corrupt-*
  /// hepsi buradan elenir).
  static ({String id, String title})? decodeFileName(String fileName) {
    final match = RegExp(r'^([0-9a-f]{16})__(.+)\.([A-Za-z0-9]+)$')
        .firstMatch(fileName);
    if (match == null) return null;
    final ext = match.group(3)!.toLowerCase();
    if (!kSupportedAudioExtensions.contains(ext)) return null;
    return (
      id: 'local-${match.group(1)!}',
      title: match.group(2)!.replaceAll('-', ' '),
    );
  }
}
