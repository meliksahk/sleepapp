import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/features/mixer/data/audio_probe.dart';
import 'package:nocta/features/mixer/data/local_sound_library_impl.dart';
import 'package:nocta/features/mixer/data/local_sound_store.dart';
import 'package:nocta/features/mixer/data/sound_picker.dart';
import 'package:nocta/features/mixer/domain/local_sound.dart';
import 'package:nocta/features/mixer/domain/local_sound_library.dart';
import 'package:path/path.dart' as p;

/// İTHAL AKIŞI — gerçek dosya sistemine karşı, eklentisiz.
///
/// Seçici ve sınayıcı arayüz olduğu için (`FakeSoundPicker`, `FakeAudioProbe`)
/// akışın TAMAMI — kapıların SIRASI, kopyalama, geri alma, temizlik — platform
/// kanalı olmadan sürülebiliyor. Kanıtlanan şey "ses duyuluyor" değil; kanıtlanan
/// şey **kullanıcının diskinde kalıntı ve yalan kayıt bırakmadığımız.**
///
/// Kaynak dosyalar AYRI bir geçici dizinde tutuluyor: kütüphane dizininde
/// "hiçbir yeni dosya yok" gibi iddiaları ancak dizin bize aitse kurabiliriz.
void main() {
  late Directory libDir;
  late Directory srcDir;
  late FakeSoundPicker picker;
  late FakeAudioProbe probe;

  LocalSoundLibraryImpl buildLibrary({LocalSoundStore? store}) =>
      LocalSoundLibraryImpl(
        dir: () async => libDir,
        picker: picker,
        probe: probe,
        store: store,
      );

  /// Kullanıcının telefonundaki dosyanın taklidi. Seçici gerçek hayatta dosyayı
  /// cache'e kopyalayıp o yolu döndürüyor; burada da öyle: gerçek bayt, gerçek yol.
  PickedSound makeSource(String displayName, {int bytes = 4096}) {
    final file = File(p.join(srcDir.path, displayName));
    file.writeAsBytesSync(List<int>.filled(bytes, 7));
    return PickedSound(
      path: file.path,
      displayName: displayName,
      sizeBytes: file.lengthSync(),
    );
  }

  List<String> libFileNames() => libDir
      .listSync()
      .whereType<File>()
      .map((f) => p.basename(f.path))
      .toList();

  /// Manifestteki kayıtlar — okunamaz hâlde testi patlatır (o hâli ayrıca
  /// sınıyoruz; buraya sızması gizli bir yanlış-pozitif olurdu).
  Future<List<LocalSound>> manifest() async {
    final index = await LocalSoundStore(dir: () async => libDir).read();
    expect(index, isA<LocalSoundIndexOk>());
    return (index as LocalSoundIndexOk).sounds;
  }

  setUp(() {
    libDir = Directory.systemTemp.createTempSync('nocta_lib_test');
    srcDir = Directory.systemTemp.createTempSync('nocta_src_test');
    picker = FakeSoundPicker();
    probe = FakeAudioProbe();
  });

  tearDown(() {
    if (libDir.existsSync()) libDir.deleteSync(recursive: true);
    if (srcDir.existsSync()) srcDir.deleteSync(recursive: true);
  });

  group('import', () {
    test('MUTLU YOL: dosya kopyalanır, kaydedilir ve id "local-" önekli olur',
        () async {
      // Önek pazarlıksız: MixerController sentez ve dosya katmanlarını TEK bir
      // gains haritasında tutuyor. Çakışan bir id, sürgünün YANLIŞ katmanı
      // oynatması demek olurdu.
      picker.result = makeSource('night rain.mp3', bytes: 4096);

      final result = await buildLibrary().import(currentAssetLayerCount: 0);

      expect(result, isA<LocalSoundImported>());
      final sound = (result as LocalSoundImported).sound;
      expect(sound.id, startsWith('local-'));
      expect(sound.id, hasLength('local-'.length + 16));
      expect(sound.title, 'night rain');
      expect(sound.sizeBytes, 4096);

      final copied = File(p.join(libDir.path, sound.fileName));
      expect(copied.existsSync(), isTrue, reason: 'hedef dizinde dosya yok');
      expect(copied.lengthSync(), 4096, reason: 'kopya eksik/kesik');

      final records = await manifest();
      expect(
        records,
        hasLength(1),
        reason: 'GERÇEK HATA: ilk ithal kaydı İKİ KEZ yazıyor. '
            '_store.mutate içindeki read(), index.json henüz yokken '
            '_rebuildFromDisk ile az önce rename edilmiş dosyayı zaten kayda '
            'çeviriyor; impl onun ÜSTÜNE bir de kendi kaydını ekliyor. '
            'Sonuç: aynı id ve aynı fileName ile iki satır. '
            'Kayıtlar: ${records.map((s) => '${s.id}/${s.fileName}').toList()}',
      );
      expect(records.single.id, sound.id);
      expect(records.single.fileName, sound.fileName);

      // Sınayıcı KOPYA üzerinde koştu, kaynak üzerinde değil: seçicinin cache
      // kopyası ile bizimki arasındaki fark (kesilmiş yazma) ancak böyle görünür.
      expect(probe.probed, <String>[copied.path]);
    });

    test('İPTAL: kullanıcı vazgeçince disk ve manifest DOKUNULMAMIŞ kalır',
        () async {
      // İptal bir HATA değil. Yarım dosya, boş kayıt, hiçbir iz bırakmamalı.
      picker.result = null;

      final result = await buildLibrary().import(currentAssetLayerCount: 0);

      expect(result, isA<LocalSoundImportRejected>());
      expect(
        (result as LocalSoundImportRejected).reason,
        LocalSoundImportFailure.cancelled,
      );
      expect(libDir.listSync(), isEmpty, reason: 'iptalde tek bayt bile yazılmamalı');
      expect(await manifest(), isEmpty);
    });

    test('TAVAN: sınır doluysa seçici HİÇ AÇILMAZ', () async {
      // Kullanıcıya dosya seçtirip sonra reddetmek boşa harcanmış bir etkileşim
      // olurdu. callCount == 0 bu sıranın tek kanıtı: tavan kontrolü seçiciden
      // ÖNCE. Sıra ters çevrilirse test kırmızıya döner.
      picker.result = makeSource('night rain.mp3');

      final result = await buildLibrary()
          .import(currentAssetLayerCount: kMaxImportedLayers);

      expect(result, isA<LocalSoundImportRejected>());
      expect(
        (result as LocalSoundImportRejected).reason,
        LocalSoundImportFailure.tooManyLayers,
      );
      expect(picker.callCount, 0, reason: 'seçici açılmış — kapı sırası bozuk');
      expect(libDir.listSync(), isEmpty);
    });

    test('ÇOK BÜYÜK dosya kopyalanmadan reddedilir (boyut kapısı önce)',
        () async {
      // Boyut kapısı kopyalamadan ÖNCE: 50 MB'ı diske yazıp sonra silmek,
      // kullanıcının diskini boşuna doldurup dolu diskte ithali öldürürdü.
      // Seyrek dosya kullanıyoruz — gerçekten 50 MB yazmıyoruz.
      final huge = File(p.join(srcDir.path, 'huge.mp3'));
      final raf = huge.openSync(mode: FileMode.write);
      raf.truncateSync(kMaxFileBytes + 1); // uzatır — 50 MB GERÇEKTEN yazılmaz
      raf.closeSync();
      picker.result = PickedSound(
        path: huge.path,
        displayName: 'huge.mp3',
        sizeBytes: huge.lengthSync(),
      );

      final result = await buildLibrary().import(currentAssetLayerCount: 0);

      expect(result, isA<LocalSoundImportRejected>());
      final rejected = result as LocalSoundImportRejected;
      expect(rejected.reason, LocalSoundImportFailure.tooLarge);
      // Kullanıcıya "sınır 50 MB" demek yetmez, "bu dosya şu kadar" demek gerekir.
      expect(rejected.sizeBytes, kMaxFileBytes + 1);
      expect(libDir.listSync(), isEmpty, reason: 'kopya alınmış');
      expect(await manifest(), isEmpty);
    });

    test('SINAMA REDDETTİ: kalıntı dosya YOK, manifest boş (geri alma çalıştı)',
        () async {
      // Bu dosyadaki en önemli test. Sınama kopyadan SONRA koşuyor; reddettiğinde
      // yarım yol kat etmiş bir ithal geriye SARILMALI. Aksi hâlde kütüphanede
      // çalınamayan bir kayıt kalırdı — kullanıcıya sessizce yalan söylemek.
      probe.failWith = LocalSoundImportFailure.notAudio;
      picker.result = makeSource('bozuk.mp3');

      final result = await buildLibrary().import(currentAssetLayerCount: 0);

      expect(result, isA<LocalSoundImportRejected>());
      expect(
        (result as LocalSoundImportRejected).reason,
        LocalSoundImportFailure.notAudio,
      );
      expect(probe.probed, hasLength(1), reason: 'sınama hiç koşmamış');
      expect(
        libDir.listSync(),
        isEmpty,
        reason: 'geri alma başarısız — diskte kalıntı var: ${libFileNames()}',
      );
      expect(await manifest(), isEmpty, reason: 'çalınamayan kayıt manifeste girdi');
    });

    test('.part TEMİZLİĞİ: başarılı ithalden sonra yarım kopya izi kalmaz',
        () async {
      // '.part' uzantısı yarım kopyayı hem uzlaştırmadan hem yeniden inşadan
      // gizliyor. Ama temizlenmezse her ithal bir dosya boyu disk SIZDIRIR.
      picker.result = makeSource('night rain.mp3', bytes: 2048);

      await buildLibrary().import(currentAssetLayerCount: 0);

      expect(
        libFileNames().where((n) => n.endsWith('.part')),
        isEmpty,
        reason: 'yarım kopya diskte kaldı',
      );
      // Beklenen tam içerik: ses dosyası + manifest. Fazlası sızıntıdır.
      expect(libFileNames(), hasLength(2));
      expect(
        libFileNames().where((n) => n == LocalSoundStore.indexFileName),
        hasLength(1),
      );
    });

    test('seçicinin cache kopyası ithal sonrası silinir (2× disk tepesi kısalır)',
        () async {
      final picked = makeSource('night rain.mp3');
      picker.result = picked;

      await buildLibrary().import(currentAssetLayerCount: 0);

      expect(File(picked.path).existsSync(), isFalse,
          reason: 'cache kopyası bırakıldı');
    });
  });

  group('delete / totalBytes', () {
    test('delete: kayıt VE dosya gider, true döner', () async {
      picker.result = makeSource('night rain.mp3');
      final library = buildLibrary();
      final imported =
          await library.import(currentAssetLayerCount: 0) as LocalSoundImported;
      final path = p.join(libDir.path, imported.sound.fileName);
      expect(File(path).existsSync(), isTrue);

      final ok = await library.delete(imported.sound.id);

      expect(ok, isTrue);
      expect(File(path).existsSync(), isFalse, reason: 'baytlar diskte kaldı');
      expect(await manifest(), isEmpty, reason: 'kayıt manifestte kaldı');
    });

    test('delete: bilinmeyen id false döner ve hiçbir şeye dokunmaz', () async {
      picker.result = makeSource('night rain.mp3');
      final library = buildLibrary();
      final imported =
          await library.import(currentAssetLayerCount: 0) as LocalSoundImported;

      final ok = await library.delete('local-0000000000000000');

      expect(ok, isFalse);
      expect(
        await manifest(),
        hasLength(1),
        reason: 'yanlış kayıt silinmiş — VEYA ilk ithalin çift kayıt hatası '
            '(bkz. MUTLU YOL testi) buraya sızdı',
      );
      expect(
        File(p.join(libDir.path, imported.sound.fileName)).existsSync(),
        isTrue,
      );
    });

    test('totalBytes: iki ithalin toplamı diskteki iki dosyanın boyutu', () async {
      // Kütüphane tavanı bu sayıya dayanıyor; yanlış toplama kullanıcıyı ya
      // erken kilitler ya da tavanı sessizce aşar.
      final library = buildLibrary();
      picker.result = makeSource('night rain.mp3', bytes: 4096);
      await library.import(currentAssetLayerCount: 0);
      picker.result = makeSource('city hum.wav', bytes: 1024);
      await library.import(currentAssetLayerCount: 1);

      expect(
        await manifest(),
        hasLength(2),
        reason: 'GERÇEK HATA: ilk ithalin çift kaydı yüzünden 3 satır var. '
            'Bunun bedeli kozmetik değil: totalBytes ilk sesi İKİ KEZ sayıyor, '
            'yani 150 MB kütüphane tavanı olduğundan erken doluyor.',
      );
      expect(await library.totalBytes(), 4096 + 1024);

      final onDisk = libDir
          .listSync()
          .whereType<File>()
          .where((f) => LocalSoundStore.decodeFileName(p.basename(f.path)) != null)
          .fold<int>(0, (sum, f) => sum + f.lengthSync());
      expect(onDisk, 4096 + 1024, reason: 'manifest ile disk ayrışmış');
    });
  });

  group('reconcile', () {
    test('KIRMIZI ÇİZGİ: indeks OKUNAMAZ iken hiçbir dosyaya DOKUNULMAZ',
        () async {
      // Bu dosyadaki ikinci kritik test. "Bilmiyorum" hâlindeyken diskteki
      // dosyaları yetim ilan edip taşımak, kullanıcının TÜM kütüphanesini geri
      // dönüşsüz yok ederdi. Gerçek bir IO hatasını taşınabilir biçimde
      // üretemediğimiz için okunamaz hâli depodan enjekte ediyoruz.
      final name = LocalSoundStore.buildFileName(
        hex: 'a1b2c3d4e5f60718',
        title: 'night rain',
        extension: 'mp3',
      );
      File(p.join(libDir.path, name)).writeAsBytesSync(List<int>.filled(64, 1));
      File(p.join(libDir.path, name)).setLastModifiedSync(
        DateTime.now().subtract(const Duration(hours: 3)),
      );
      final store = _UnreadableStore(dir: () async => libDir);

      final report = await buildLibrary(store: store).reconcile();

      expect(report.isClean, isTrue);
      expect(report.orphanFiles, 0);
      expect(report.droppedRecords, 0);
      expect(File(p.join(libDir.path, name)).existsSync(), isTrue,
          reason: 'okunamaz indekste dosya taşındı/silindi');
      expect(Directory(p.join(libDir.path, '_orphan')).existsSync(), isFalse);
      expect(store.mutateCalls, 0, reason: 'okunamaz indeksin üstüne yazıldı');
    });

    test('BOZUK MANİFEST + diskte dosyalar: hiçbiri silinmez/taşınmaz', () async {
      // Bozuk manifest yeniden inşayı tetikler; inşa edilen kayıtlar diskteki
      // dosyaların TAMAMINI kapsadığı için uzlaştırmanın taşıyacak yetimi olmaz.
      // Bu iki mekanizmanın (kurtarma + uzlaştırma) birbirini yemediğini kilitler.
      final names = <String>[
        LocalSoundStore.buildFileName(
            hex: 'a1b2c3d4e5f60718', title: 'night rain', extension: 'mp3'),
        LocalSoundStore.buildFileName(
            hex: '00112233445566ff', title: 'city hum', extension: 'wav'),
      ];
      final old = DateTime.now().subtract(const Duration(hours: 3));
      for (final n in names) {
        final f = File(p.join(libDir.path, n))
          ..writeAsBytesSync(List<int>.filled(64, 1));
        f.setLastModifiedSync(old); // "taze koruması" bu testi kurtarmasın
      }
      File(p.join(libDir.path, LocalSoundStore.indexFileName))
          .writeAsStringSync('{bozuk');

      final report = await buildLibrary().reconcile();

      expect(report.orphanFiles, 0, reason: 'kurtarılmış ses yetim sanıldı');
      expect(report.droppedRecords, 0);
      for (final n in names) {
        expect(File(p.join(libDir.path, n)).existsSync(), isTrue,
            reason: '$n kayboldu');
      }
      expect(Directory(p.join(libDir.path, '_orphan')).existsSync(), isFalse);
    });

    test('kayıt var dosya yok: kayıt düşer, droppedRecords artar', () async {
      // Kullanıcı dosyayı başka bir yoldan sildiyse (iOS depolama temizliği,
      // Android dosya yöneticisi) arayüz çalmayan bir satır göstermemeli.
      final store = LocalSoundStore(dir: () async => libDir);
      final alive = LocalSoundStore.buildFileName(
          hex: 'a1b2c3d4e5f60718', title: 'night rain', extension: 'mp3');
      File(p.join(libDir.path, alive)).writeAsBytesSync(List<int>.filled(64, 1));
      await store.write(<LocalSound>[
        LocalSound(
          id: 'local-a1b2c3d4e5f60718',
          title: 'night rain',
          fileName: alive,
          sizeBytes: 64,
          importedAt: DateTime.utc(2026, 3, 14),
        ),
        LocalSound(
          id: 'local-00112233445566ff',
          title: 'hayalet',
          fileName: LocalSoundStore.buildFileName(
              hex: '00112233445566ff', title: 'hayalet', extension: 'mp3'),
          sizeBytes: 128,
          importedAt: DateTime.utc(2026, 3, 15),
        ),
      ]);

      final report = await buildLibrary().reconcile();

      expect(report.droppedRecords, 1);
      expect(report.isClean, isFalse);
      final records = await manifest();
      expect(records, hasLength(1));
      expect(records.single.title, 'night rain');
      expect(File(p.join(libDir.path, alive)).existsSync(), isTrue,
          reason: 'sağlam dosya da silinmiş');
    });

    test('YETİM dosya SİLİNMEZ, _orphan/ altına taşınır', () async {
      // Silmek geri alınamaz. Karantina, hatalı bir yetim teşhisinde kullanıcının
      // sesini kurtarma şansını açık bırakır.
      final store = LocalSoundStore(dir: () async => libDir);
      await store.write(const <LocalSound>[]); // geçerli ve BOŞ manifest
      final orphan = LocalSoundStore.buildFileName(
          hex: 'a1b2c3d4e5f60718', title: 'unutulmus', extension: 'mp3');
      File(p.join(libDir.path, orphan))
        ..writeAsBytesSync(List<int>.filled(256, 3))
        ..setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 2)));

      final report = await buildLibrary().reconcile();

      expect(report.orphanFiles, 1);
      expect(report.orphanBytes, 256);
      expect(File(p.join(libDir.path, orphan)).existsSync(), isFalse,
          reason: 'yetim yerinde kalmış');
      expect(
        File(p.join(libDir.path, '_orphan', orphan)).existsSync(),
        isTrue,
        reason: 'yetim SİLİNMİŞ — karantina yerine yok edilmiş',
      );
    });

    test('TAZE yetim DOKUNULMAZ (devam eden ithali öldürmeme koruması)',
        () async {
      // Az önce rename edilmiş ama henüz manifeste yazılmamış bir dosya, başka
      // bir isolate'tan koşan uzlaştırma tarafından yetim sanılırdı. 10 dakikalık
      // taze penceresi kullanıcının gözü önünde ithali öldürmeyi engelliyor.
      final store = LocalSoundStore(dir: () async => libDir);
      await store.write(const <LocalSound>[]);
      final fresh = LocalSoundStore.buildFileName(
          hex: 'a1b2c3d4e5f60718', title: 'yeni gelen', extension: 'mp3');
      File(p.join(libDir.path, fresh))
          .writeAsBytesSync(List<int>.filled(256, 3)); // mtime = şimdi

      final report = await buildLibrary().reconcile();

      expect(report.orphanFiles, 0, reason: 'taze dosya yetim sayıldı');
      expect(report.isClean, isTrue);
      expect(File(p.join(libDir.path, fresh)).existsSync(), isTrue);
      expect(Directory(p.join(libDir.path, '_orphan')).existsSync(), isFalse);
    });
  });

  group('pathOf', () {
    test('mutlak yol her çağrıda GÜNCEL dizinden üretilir', () async {
      // Kaydın yalnızca dosya ADI tutmasının bütün amacı bu: iOS konteyner
      // UUID'si değişince yol da değişmeli, kayıt değil.
      picker.result = makeSource('night rain.mp3');
      final library = buildLibrary();
      final imported =
          await library.import(currentAssetLayerCount: 0) as LocalSoundImported;

      final path = await library.pathOf(imported.sound);

      expect(path, p.join(libDir.path, imported.sound.fileName));
      expect(File(path).existsSync(), isTrue);
      // Manifestte yol değil, ad var.
      final raw = jsonDecode(
        File(p.join(libDir.path, LocalSoundStore.indexFileName))
            .readAsStringSync(),
      ) as Map;
      final entries = (raw['sounds']! as List).cast<Map<String, Object?>>();
      expect(
        entries,
        hasLength(1),
        reason: 'GERÇEK HATA: tek ithal iki kayıt yazdı (bkz. MUTLU YOL testi)',
      );
      final stored = entries.first['fileName']! as String;
      expect(stored, isNot(contains(libDir.path)));
      expect(stored, imported.sound.fileName);
    });
  });
}

/// İndeksin OKUNAMAZ olduğu hâli üretir.
///
/// Gerçek `LocalSoundIndexUnreadable` yalnızca bir `FileSystemException` ile
/// doğuyor; onu Windows/macOS/Linux'ta aynı şekilde tetiklemenin taşınabilir bir
/// yolu yok (izin/chmod hileleri Windows'ta çalışmıyor). Depo enjekte edilebilir
/// olduğu için o hâli buradan veriyoruz — sınanan şey deponun IO'su değil,
/// uzlaştırmanın o hâle verdiği CEVAP.
class _UnreadableStore extends LocalSoundStore {
  _UnreadableStore({required super.dir});

  int mutateCalls = 0;

  @override
  Future<LocalSoundIndex> read() async => const LocalSoundIndexUnreadable();

  @override
  Future<void> mutate(
    List<LocalSound> Function(List<LocalSound> current) change,
  ) async {
    mutateCalls++;
  }
}
