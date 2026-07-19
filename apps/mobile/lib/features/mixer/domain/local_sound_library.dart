import 'local_sound.dart';

/// İthal edilen seslerin kütüphanesi — cihazdaki tek doğruluk kaynağı.
///
/// **Sunucuya HİÇBİR ŞEY gitmez.** `audio_assets` tablosunda `user_id` ve
/// repository scoping YOK; oraya kullanıcı dosyası yazmak CLAUDE.md §6 ihlali ve
/// doğrudan bir yetkilendirme açığı olurdu. Bu özellik bilerek ve tamamen
/// cihazda kalır — bedeli, kullanıcının telefon değiştirdiğinde kütüphanesini
/// kaybetmesidir (bkz. DURUM RAPORU).
abstract class LocalSoundLibrary {
  Future<LocalSoundIndex> list();

  /// Seçiciyi açar, dosyayı kopyalar, çalınabilirliğini sınar ve kaydeder.
  ///
  /// [currentAssetLayerCount] tavan kontrolü için: tavan aşılıysa seçici HİÇ
  /// açılmaz (kullanıcıya dosya seçtirip sonra reddetmek, boşa harcanmış bir
  /// etkileşim olurdu).
  Future<LocalSoundImportResult> import({required int currentAssetLayerCount});

  /// Kaydı VE dosyayı siler. Kullanıcının telefonundaki ORİJİNAL dosyaya dokunmaz.
  Future<bool> delete(String id);

  Future<int> totalBytes();

  /// Kaydın var olduğu ama dosyanın kaybolduğu durumları temizler.
  ///
  /// **KIRMIZI ÇİZGİ:** yalnızca [LocalSoundIndexOk] hâlinde koşar. İndeks
  /// okunamıyorken "diskte var, indekste yok" diye dosya silmek, kullanıcının
  /// tüm kütüphanesini geri dönüşsüz yok ederdi — "bilmiyorum" hâlindeyken
  /// silmek yasak.
  Future<LocalSoundReconcileReport> reconcile();

  /// [LocalSound]'un diskteki mutlak yolu. Kayıt yalnızca dosya ADI tuttuğu için
  /// (bkz. [LocalSound.fileName]) yol her seferinde GÜNCEL dizinle üretilir.
  Future<String> pathOf(LocalSound sound);
}

/// "Boş" ile "okunamadı" **AYRI tiplerdir.**
///
/// Bu ayrım dekoratif değil: ikisini `List<LocalSound>` altında birleştirmek,
/// okunamayan bir indeksi "kütüphane boş" sayıp ardından diskteki her dosyayı
/// yetim ilan etmek demekti. Tip sistemi bu hatayı imkânsız kılıyor.
sealed class LocalSoundIndex {
  const LocalSoundIndex();
}

class LocalSoundIndexOk extends LocalSoundIndex {
  const LocalSoundIndexOk(this.sounds);
  final List<LocalSound> sounds;
}

class LocalSoundIndexUnreadable extends LocalSoundIndex {
  const LocalSoundIndexUnreadable();
}

/// Test/mock — bellekte, dosya sistemine dokunmaz.
///
/// `InMemoryArchetypeStore` ile aynı gerekçe: widget testlerinin `path_provider`
/// platform kanalına uzanması gerekmesin. **Bu olmadan** gerçek uygulama
/// kabuğunu kuran her test `MissingPluginException` ile düşer.
class InMemoryLocalSoundLibrary implements LocalSoundLibrary {
  InMemoryLocalSoundLibrary({
    List<LocalSound>? sounds,
    this.unreadable = false,
    this.importResult,
    this.deleteSucceeds = true,
  }) : _sounds = <LocalSound>[...?sounds];

  final List<LocalSound> _sounds;

  /// "Okunamadı" hâlini de test edebilmek için — bu ayrımın kaybolması, tüm
  /// kütüphaneyi silen hatanın geri dönmesi demek.
  bool unreadable;

  /// `null` → mutlu yol: yeni bir kayıt üretilip listeye eklenir.
  LocalSoundImportResult? importResult;
  bool deleteSucceeds;

  int importCallCount = 0;

  @override
  Future<LocalSoundIndex> list() async =>
      unreadable ? const LocalSoundIndexUnreadable() : LocalSoundIndexOk(_sounds);

  @override
  Future<LocalSoundImportResult> import({
    required int currentAssetLayerCount,
  }) async {
    importCallCount++;
    final result = importResult;
    if (result != null) return result;
    final sound = LocalSound(
      id: 'local-${_sounds.length.toString().padLeft(16, '0')}',
      title: 'Ses ${_sounds.length + 1}',
      fileName: '${_sounds.length.toString().padLeft(16, '0')}__ses.mp3',
      sizeBytes: 1024,
      importedAt: DateTime.utc(2026),
    );
    _sounds.add(sound);
    return LocalSoundImported(sound);
  }

  @override
  Future<bool> delete(String id) async {
    if (!deleteSucceeds) return false;
    _sounds.removeWhere((s) => s.id == id);
    return true;
  }

  @override
  Future<int> totalBytes() async =>
      _sounds.fold<int>(0, (sum, s) => sum + s.sizeBytes);

  @override
  Future<LocalSoundReconcileReport> reconcile() async =>
      const LocalSoundReconcileReport();

  @override
  Future<String> pathOf(LocalSound sound) async => '/tmp/nocta/${sound.fileName}';
}

/// [LocalSoundLibrary.reconcile] sonucu — kullanıcıya ne söyleneceğini belirler.
class LocalSoundReconcileReport {
  const LocalSoundReconcileReport({
    this.droppedRecords = 0,
    this.orphanFiles = 0,
    this.orphanBytes = 0,
  });

  /// İndekste vardı, diskte yoktu → kayıt düşürüldü.
  final int droppedRecords;

  /// Diskte vardı, indekste yoktu → **silinmedi**, karantinaya taşındı.
  final int orphanFiles;
  final int orphanBytes;

  bool get isClean => droppedRecords == 0 && orphanFiles == 0;
}
