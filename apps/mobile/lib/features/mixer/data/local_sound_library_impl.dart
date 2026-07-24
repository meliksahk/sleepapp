import 'dart:io';
import 'dart:math' show Random;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;

import '../domain/local_sound.dart';
import '../domain/local_sound_library.dart';
import 'audio_probe.dart';
import 'local_sound_store.dart';
import 'sound_picker.dart';

/// Tek dosya için üst sınır.
const int kMaxFileBytes = 50 * 1024 * 1024;

/// Kütüphane toplamı için üst sınır.
///
/// **Neden 300 değil 150:** iOS'ta `Library/Application Support` iCloud yedeğine
/// GİRER (yedekten muaf olan yalnızca `Library/Caches` ve `tmp`'dir). Muafiyet
/// `NSURLIsExcludedFromBackupKey` gerektirir; bu native bir çağrıdır ve
/// path_provider yapmaz — bu sürümde YAPILMIYOR (bkz. DURUM RAPORU). Kullanıcının
/// iCloud kotasına sessizce 300 MB yazmak kabul edilemezdi.
const int kMaxLibraryBytes = 150 * 1024 * 1024;

/// Aynı anda mikste çalabilecek azami DOSYA katmanı.
///
/// ⚠️ **CİHAZDA ÖLÇÜLMEDİ.** Eşzamanlı MediaCodec/AudioPlayer sınırı cihaza ve
/// SoC'a bağlı; ayrıca sentez katmanlarının (ham PCM) decoder harcayıp
/// harcamadığından emin değilim. 5, ölçülmüş bir tavan değil, bilinen bir duvara
/// kullanıcıyı çarptırmamak için konmuş yumuşak bir sınırdır.
const int kMaxImportedLayers = 5;

/// İthal akışının orkestrasyonu.
class LocalSoundLibraryImpl implements LocalSoundLibrary {
  LocalSoundLibraryImpl({
    required Future<Directory> Function() dir,
    required this.picker,
    required this.probe,
    LocalSoundStore? store,
    Random? random,
  })  : _dir = dir,
        _store = store ?? LocalSoundStore(dir: dir),
        _random = random ?? Random.secure();

  final Future<Directory> Function() _dir;
  final SoundPicker picker;
  final AudioProbe probe;
  final LocalSoundStore _store;
  final Random _random;

  /// Devam eden bir ithal varken uzlaştırma KOŞMAZ: yarısı kopyalanmış bir
  /// dosyayı yetim sanıp karantinaya almak, kullanıcının gözü önünde ithali
  /// öldürmek olurdu.
  bool _importInFlight = false;

  @override
  Future<LocalSoundIndex> list() => _store.read();

  @override
  Future<String> pathOf(LocalSound sound) async =>
      p.join((await _dir()).path, sound.fileName);

  @override
  Future<int> totalBytes() async {
    final index = await _store.read();
    if (index is! LocalSoundIndexOk) return 0;
    return index.sounds.fold<int>(0, (sum, s) => sum + s.sizeBytes);
  }

  @override
  Future<LocalSoundImportResult> import({
    required int currentAssetLayerCount,
  }) async {
    // (1) TAVAN — seçiciden ÖNCE. Kullanıcıya dosya seçtirip sonra reddetmek,
    // boşa harcanmış bir etkileşim olurdu.
    if (currentAssetLayerCount >= kMaxImportedLayers) {
      return const LocalSoundImportRejected(
        LocalSoundImportFailure.tooManyLayers,
      );
    }

    // (2) SEÇ — null vazgeçmedir, hata değil.
    final PickedSound? picked;
    try {
      picked = await picker.pick();
    } on SoundPickerException catch (e) {
      debugPrint('nocta.localsound: seçici açılamadı: $e');
      return const LocalSoundImportRejected(
        LocalSoundImportFailure.pickerFailed,
      );
    }
    if (picked == null) {
      return const LocalSoundImportRejected(LocalSoundImportFailure.cancelled);
    }

    // (3) BOYUT KAPILARI — kopyalamadan önce, diski boşuna doldurmamak için.
    if (picked.sizeBytes > kMaxFileBytes) {
      await _discardPickerCopy(picked);
      return LocalSoundImportRejected(
        LocalSoundImportFailure.tooLarge,
        sizeBytes: picked.sizeBytes,
      );
    }
    final used = await totalBytes();
    if (used + picked.sizeBytes > kMaxLibraryBytes) {
      await _discardPickerCopy(picked);
      return LocalSoundImportRejected(
        LocalSoundImportFailure.libraryFull,
        sizeBytes: picked.sizeBytes,
        usedBytes: used,
      );
    }

    final hex = _hex16();
    final ext = _extensionOf(picked.displayName);
    final fileName = LocalSoundStore.buildFileName(
      hex: hex,
      title: _titleOf(picked.displayName),
      extension: ext,
    );

    _importInFlight = true;
    final dir = await _dir();
    final partPath = p.join(dir.path, '$fileName.part');
    final finalPath = p.join(dir.path, fileName);

    try {
      if (!await dir.exists()) await dir.create(recursive: true);

      // (4) PARÇALI KOPYA. 50 MB'ı belleğe almak yasak; ayrıca yarım kopya
      // ASLA nihai adı almaz — `.part` uzantısı onu hem uzlaştırmadan hem de
      // yeniden inşadan gizler.
      await _copyStreaming(picked.path, partPath);

      // (5) RENAME — bu andan itibaren dosya "gerçek".
      await File(partPath).rename(finalPath);

      // (6) SINA. Kopyadan SONRA, çünkü sınamayı önce yapıp sonra kopyalasaydık
      // seçicinin cache kopyası ile bizimki arasındaki fark (kesilmiş yazma)
      // gözden kaçardı.
      await probe.probe(finalPath);

      // (7) KAYDET.
      final sound = LocalSound(
        id: 'local-$hex',
        title: _titleOf(picked.displayName),
        fileName: fileName,
        sizeBytes: await File(finalPath).length(),
        importedAt: DateTime.now().toUtc(),
      );
      // ⚠️ EKLEME DEĞİL, **ÜSTÜNE YAZMA** — ve bu bir hata düzeltmesi.
      //
      // Naif `[...current, sound]` ilk ithalde kaydı İKİ KEZ yazıyordu:
      // `mutate` önce `read()` yapar, `index.json` henüz yokken `read()`
      // diskten yeniden inşa dalına girer ve (5)'te rename edilmiş nihai
      // dosyayı ZATEN bir kayda çevirir; sonra biz kendi kaydımızı eklerdik.
      // Sonuç aynı id'den iki satır: `totalBytes()` çift sayar (150 MB tavanı
      // erken dolar) ve tek `gains` haritası yüzünden sürgü belirsizleşir.
      // HER kullanıcının İLK ithalinde oluyordu.
      //
      // Aynı id'yi eleyip kendimizinkini yazmak hem tekilleştirir hem de doğru
      // kaydı seçer: bizimki kullanıcının GERÇEK dosya adını ve UTC damgasını
      // taşır, yeniden inşa edilen ise başlığı slug'dan tahmin eder.
      await _store.mutate((current) => <LocalSound>[
            for (final s in current)
              if (s.id != sound.id) s,
            sound,
          ]);
      await _discardPickerCopy(picked);
      return LocalSoundImported(sound);
    } on LocalSoundImportFailure catch (reason) {
      // Sınama reddetti — kopyayı GERİ AL. Kütüphanede çalınamayan bir kayıt
      // bırakmak, kullanıcıya sessizce yalan söylemek olurdu.
      await _deleteQuietly(finalPath);
      return LocalSoundImportRejected(reason);
    } on PathNotFoundException catch (e) {
      debugPrint('nocta.localsound: kaynak kayboldu: $e');
      await _deleteQuietly(finalPath);
      return const LocalSoundImportRejected(LocalSoundImportFailure.sourceGone);
    } on FileSystemException catch (e) {
      await _deleteQuietly(finalPath);
      // ENOSPC (28) VE yazma sırasında gelen tanınmayan her IO hatası noSpace'e
      // yönlendirilir: `unknown` kullanıcıya "tekrar dene" dedirtir ve dolu
      // diskte onu sonsuz bir döngüde kilitler.
      final code = e.osError?.errorCode;
      debugPrint('nocta.localsound: kopyalama hatası (os=$code): $e');
      return const LocalSoundImportRejected(LocalSoundImportFailure.noSpace);
    } catch (e, st) {
      await _deleteQuietly(finalPath);
      debugPrint('nocta.localsound: beklenmeyen ithal hatası: $e\n$st');
      return const LocalSoundImportRejected(LocalSoundImportFailure.unknown);
    } finally {
      // TEMİZLİK TEK YERDE: her hata dalına ayrı ayrı dağıtmak, bir dalı
      // unutmanın sessizce disk sızdırması demekti.
      await _deleteQuietly(partPath);
      _importInFlight = false;
    }
  }

  @override
  Future<bool> delete(String id) async {
    final index = await _store.read();
    if (index is! LocalSoundIndexOk) return false;
    LocalSound? target;
    for (final s in index.sounds) {
      if (s.id == id) target = s;
    }
    if (target == null) return false;

    final path = p.join((await _dir()).path, target.fileName);
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException catch (e) {
      // Kayıt KORUNUR: dosyayı silemediysek kaydı silmek, ulaşılamaz bir yetim
      // üretmek olurdu (bayt diskte, kullanıcının onu görecek arayüzü yok).
      debugPrint('nocta.localsound: dosya silinemedi: $e');
      return false;
    }
    await _store.mutate(
      (current) => <LocalSound>[
        for (final s in current)
          if (s.id != id) s,
      ],
    );
    return true;
  }

  @override
  Future<LocalSoundReconcileReport> reconcile() async {
    if (_importInFlight) return const LocalSoundReconcileReport();

    final index = await _store.read();
    // KIRMIZI ÇİZGİ: "bilmiyorum" hâlindeyken hiçbir şeye dokunma.
    if (index is! LocalSoundIndexOk) return const LocalSoundReconcileReport();

    final dir = await _dir();
    if (!await dir.exists()) return const LocalSoundReconcileReport();

    // (a) Kayıt var, dosya yok → kayıt düşürülür.
    final alive = <LocalSound>[];
    var dropped = 0;
    for (final s in index.sounds) {
      if (await File(p.join(dir.path, s.fileName)).exists()) {
        alive.add(s);
      } else {
        dropped++;
      }
    }
    if (dropped > 0) {
      await _store.mutate((_) => alive);
    }

    // (b) Dosya var, kayıt yok → **SİLİNMEZ**, karantinaya taşınır.
    final known = <String>{for (final s in alive) s.fileName};
    var orphanFiles = 0;
    var orphanBytes = 0;
    final cutoff = DateTime.now().subtract(const Duration(minutes: 10));
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (known.contains(name)) continue;
        // Sözleşmeye uymayanlar (index.json, .part, .corrupt-*) hiç değerlendirilmez.
        if (LocalSoundStore.decodeFileName(name) == null) continue;
        final stat = await entity.stat();
        // Taze dosyalara dokunma: az önce rename edilmiş ama henüz indekse
        // yazılmamış bir ithal, aksi hâlde yetim sanılırdı.
        if (stat.modified.isAfter(cutoff)) continue;
        final orphanDir = Directory(p.join(dir.path, '_orphan'));
        if (!await orphanDir.exists()) await orphanDir.create(recursive: true);
        await entity.rename(p.join(orphanDir.path, name));
        orphanFiles++;
        orphanBytes += stat.size;
      }
    } on FileSystemException catch (e) {
      debugPrint('nocta.localsound: uzlaştırma yarım kaldı: $e');
    }

    return LocalSoundReconcileReport(
      droppedRecords: dropped,
      orphanFiles: orphanFiles,
      orphanBytes: orphanBytes,
    );
  }

  // ---------------------------------------------------------------------------

  /// `openRead().pipe(openWrite())` — dosya belleğe ALINMAZ.
  Future<void> _copyStreaming(String from, String to) async {
    final sink = File(to).openWrite();
    try {
      await File(from).openRead().pipe(sink);
    } finally {
      await sink.close();
    }
  }

  /// Seçicinin cache'e bıraktığı kopyayı siler — 2× disk tepesini kısaltır.
  /// Silinemezse sorun değil: OS cache'i zaten kendi temizler.
  Future<void> _discardPickerCopy(PickedSound picked) =>
      _deleteQuietly(picked.path);

  Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException catch (e) {
      debugPrint('nocta.localsound: temizlenemedi ($path): $e');
    }
  }

  String _hex16() {
    const digits = '0123456789abcdef';
    final buffer = StringBuffer();
    for (var i = 0; i < 16; i++) {
      buffer.write(digits[_random.nextInt(16)]);
    }
    return buffer.toString();
  }

  static String _extensionOf(String displayName) {
    final dot = displayName.lastIndexOf('.');
    if (dot < 0 || dot == displayName.length - 1) return 'mp3';
    final ext = displayName.substring(dot + 1).toLowerCase();
    return kSupportedAudioExtensions.contains(ext) ? ext : 'mp3';
  }

  static String _titleOf(String displayName) {
    final dot = displayName.lastIndexOf('.');
    final base = dot > 0 ? displayName.substring(0, dot) : displayName;
    return base.trim().isEmpty ? 'Ses' : base.trim();
  }
}
