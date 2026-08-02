import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/features/mixer/data/local_sound_store.dart';
import 'package:nocta/features/mixer/domain/local_sound.dart';
import 'package:nocta/features/mixer/domain/local_sound_library.dart';
import 'package:path/path.dart' as p;

/// İthal edilen seslerin MANİFESTİ — gerçek dosya sistemine karşı.
///
/// Burada mock YOK: `path_provider` mock'lanmıyor, bellek içi sahte dosya sistemi
/// kullanılmıyor. Sebep, bu deponun vaadinin ta kendisi: "uygulamayı kapatıp
/// açtığında dosyaların yerinde". Bellekte yaşayan bir sahte, o vaadi
/// sınayamazdı — deserializasyon hiç koşmazdı (bkz. `LocalSoundStore` başlığındaki
/// shared_preferences gerekçesi).
///
/// Kilitlenen davranışlar üç öbekte:
/// 1. round-trip + GERÇEK yeniden açılış,
/// 2. bozulmaya karşı ÜÇ AYRI cevap (yeniden inşa / kayıt atlama / karantina),
/// 3. dosya adı sözleşmesi (mutlak yol yok, dizin dışına çıkma yok).
void main() {
  late Directory libDir;

  /// Kayıtların gerçek dosya adı üreticisinden geçmesi önemli: testin elle
  /// uydurduğu bir ad, üretimdeki sözleşmeyi değil testin hayalini kilitlerdi.
  LocalSound sound({
    required String hex,
    required String title,
    String extension = 'mp3',
    int sizeBytes = 1024,
    DateTime? importedAt,
  }) =>
      LocalSound(
        id: 'local-$hex',
        title: title,
        fileName: LocalSoundStore.buildFileName(
          hex: hex,
          title: title,
          extension: extension,
        ),
        sizeBytes: sizeBytes,
        importedAt: importedAt ?? DateTime.utc(2026, 3, 14, 21, 5, 9),
      );

  LocalSoundStore storeOn(Directory dir) =>
      LocalSoundStore(dir: () async => dir);

  File indexFile() => File(p.join(libDir.path, LocalSoundStore.indexFileName));

  /// Diskteki gerçek bir ses dosyası — içeriği önemsiz, ADI sözleşmeye uygun.
  /// Yeniden inşa kimliği dosya ADINDAN okuduğu için içerik gerekmiyor.
  File touchSound(String fileName, {int bytes = 8}) {
    final f = File(p.join(libDir.path, fileName));
    f.writeAsBytesSync(List<int>.filled(bytes, 0));
    return f;
  }

  List<String> namesOnDisk() => libDir
      .listSync()
      .whereType<File>()
      .map((f) => p.basename(f.path))
      .toList();

  setUp(() {
    libDir = Directory.systemTemp.createTempSync('nocta_sounds_test');
  });

  tearDown(() {
    if (libDir.existsSync()) libDir.deleteSync(recursive: true);
  });

  group('round-trip', () {
    test('yazılan kayıtlar aynı alanlarla geri okunur', () async {
      // En temel sözleşme: yazdığın şey, yazdığın gibi geri gelir. Bu kırılırsa
      // aşağıdaki hiçbir kurtarma senaryosunun anlamı kalmaz.
      final store = storeOn(libDir);
      final a = sound(hex: 'a1b2c3d4e5f60718', title: 'night rain');
      final b = sound(
        hex: '00112233445566ff',
        title: 'city hum',
        extension: 'wav',
        sizeBytes: 4096,
        importedAt: DateTime.utc(2026, 4, 1, 3, 30),
      );

      await store.write(<LocalSound>[a, b]);
      final index = await store.read();

      expect(index, isA<LocalSoundIndexOk>());
      final sounds = (index as LocalSoundIndexOk).sounds;
      expect(sounds, hasLength(2));
      expect(sounds.map((s) => s.id), <String>[a.id, b.id]);
      expect(sounds.map((s) => s.title), <String>['night rain', 'city hum']);
      expect(sounds.map((s) => s.fileName), <String>[a.fileName, b.fileName]);
      expect(sounds.map((s) => s.sizeBytes), <int>[1024, 4096]);
      expect(
        sounds.map((s) => s.importedAt.toUtc().toIso8601String()),
        <String>[
          a.importedAt.toIso8601String(),
          b.importedAt.toIso8601String(),
        ],
      );
    });

    test('GERÇEK yeniden açılış: taze bir store aynı kayıtları bulur', () async {
      // "Uygulamayı kapatıp açınca dosyan orada" vaadinin testi. TAZE bir store
      // örneği kuruyoruz: hiçbir bellek içi durum paylaşılmıyor, JSON gerçekten
      // diskten okunup yeniden çözülüyor.
      final first = storeOn(libDir);
      await first.write(<LocalSound>[
        sound(hex: 'a1b2c3d4e5f60718', title: 'night rain'),
        sound(hex: '00112233445566ff', title: 'city hum'),
      ]);

      final reopened = storeOn(libDir); // yeni süreç taklidi
      final index = await reopened.read();

      expect(index, isA<LocalSoundIndexOk>());
      final sounds = (index as LocalSoundIndexOk).sounds;
      expect(sounds, hasLength(2));
      expect(
        sounds.map((s) => s.title),
        <String>['night rain', 'city hum'],
      );
    });
  });

  group('dosya adı sözleşmesi', () {
    test('MUTLAK YOL YAZILMAZ: kaydedilen hiçbir fileName ayraç içermez',
        () async {
      // iOS'ta uygulama konteyner UUID'si güncellemede DEĞİŞİR. Mutlak yol
      // saklasaydık bir güncelleme kullanıcının TÜM kütüphanesini "dosya yok"
      // durumuna düşürürdü. Ayracın diske hiç girmediğini burada kilitliyoruz.
      final store = storeOn(libDir);
      await store.write(<LocalSound>[
        sound(hex: 'a1b2c3d4e5f60718', title: 'night rain'),
        sound(hex: '00112233445566ff', title: 'C:/uydurma/yol/ses'),
        sound(hex: 'ffeeddccbbaa9988', title: r'..\..\kacis'),
      ]);

      final raw = jsonDecode(indexFile().readAsStringSync()) as Map;
      final entries = (raw['sounds']! as List).cast<Map<String, Object?>>();
      expect(entries, hasLength(3));
      for (final e in entries) {
        final fileName = e['fileName']! as String;
        expect(fileName, isNot(contains('/')), reason: 'POSIX ayracı sızdı');
        expect(fileName, isNot(contains(r'\')), reason: 'Windows ayracı sızdı');
        expect(p.basename(fileName), fileName,
            reason: 'ad tek parça olmalı, yol değil');
      }
    });

    test("fileName'i '../escape.mp3' olan kayıt ATLANIR, kalan yaşar", () async {
      // Dizin dışına çıkma denemesi: kaydın kendisi reddedilir ama manifestin
      // tamamı feda EDİLMEZ.
      expect(
        LocalSound.fromJson(<String, Object?>{
          'schema': 1,
          'id': 'local-a1b2c3d4e5f60718',
          'title': 'kacis',
          'fileName': '../escape.mp3',
          'sizeBytes': 10,
          'importedAt': '2026-03-14T21:05:09.000Z',
        }),
        isNull,
        reason: 'ayraç taşıyan ad ayrıştırılmamalı',
      );

      indexFile().writeAsStringSync(jsonEncode(<String, Object?>{
        'schemaVersion': LocalSoundStore.fileSchemaVersion,
        'sounds': <Map<String, Object?>>[
          <String, Object?>{
            'schema': 1,
            'id': 'local-a1b2c3d4e5f60718',
            'title': 'kacis',
            'fileName': '../escape.mp3',
            'sizeBytes': 10,
            'importedAt': '2026-03-14T21:05:09.000Z',
          },
          sound(hex: '00112233445566ff', title: 'city hum').toJson(),
        ],
      }));

      final index = await storeOn(libDir).read();
      expect(index, isA<LocalSoundIndexOk>());
      final sounds = (index as LocalSoundIndexOk).sounds;
      expect(sounds, hasLength(1));
      expect(sounds.single.title, 'city hum');
    });
  });

  group('bozulma: diskten yeniden inşa', () {
    test('bozuk JSON: dosyalar SİLİNMEZ, kayıtlar diskten kurtarılır', () async {
      // Bu deponun varlık sebebi. Manifest çöp olsa bile dosya sistemi İKİNCİ
      // doğruluk kaynağıdır: kullanıcı en fazla ithal SIRASINI kaybeder,
      // SESLERİNİ kaybetmez. Ayrıca bozuk manifest silinmez, karantinaya alınır.
      final files = <String>[
        LocalSoundStore.buildFileName(
            hex: 'a1b2c3d4e5f60718', title: 'night rain', extension: 'mp3'),
        LocalSoundStore.buildFileName(
            hex: '00112233445566ff', title: 'city hum', extension: 'wav'),
        LocalSoundStore.buildFileName(
            hex: 'ffeeddccbbaa9988', title: 'deep drone', extension: 'flac'),
      ];
      for (final f in files) {
        touchSound(f);
      }
      indexFile().writeAsStringSync('{bozuk');

      final index = await storeOn(libDir).read();

      expect(index, isA<LocalSoundIndexOk>(),
          reason: 'ayrıştırma hatası "okunamadı" DEĞİL, kurtarılabilir bir hâl');
      final sounds = (index as LocalSoundIndexOk).sounds;
      expect(sounds, hasLength(3), reason: 'üç dosya, üç kayıt');

      // Baytlar duruyor — kurtarma yıkıcı değil.
      for (final f in files) {
        expect(File(p.join(libDir.path, f)).existsSync(), isTrue,
            reason: '$f silinmiş');
      }

      // Bozuk manifest silinmedi, yeniden adlandırıldı: elle inceleme mümkün.
      expect(
        namesOnDisk().where(
          (n) => n.startsWith('${LocalSoundStore.indexFileName}.corrupt-'),
        ),
        hasLength(1),
        reason: 'karantina dosyası yok',
      );

      // Başlıklar slug'dan türedi: kullanıcı 'local-a1b2...' gibi 3 anlamsız
      // satır değil, kendi verdiği adları görüyor. Kimliğin dosya ADINDA
      // yaşamasının bütün kazancı bu.
      expect(
        sounds.map((s) => s.title).toSet(),
        <String>{'night rain', 'city hum', 'deep drone'},
      );
      expect(
        sounds.map((s) => s.id).toSet(),
        <String>{
          'local-a1b2c3d4e5f60718',
          'local-00112233445566ff',
          'local-ffeeddccbbaa9988',
        },
      );
    });

    test('tanınmayan schemaVersion (99) da diskten yeniden inşa ettirir',
        () async {
      // Geriye dönük uyumsuz bir manifest (ileri sürümden geri dönüş) bozuk
      // JSON ile AYNI muameleyi görmeli: veri kaybı değil, yeniden inşa.
      final fileName = LocalSoundStore.buildFileName(
          hex: 'a1b2c3d4e5f60718', title: 'night rain', extension: 'mp3');
      touchSound(fileName, bytes: 32);
      indexFile().writeAsStringSync(jsonEncode(<String, Object?>{
        'schemaVersion': 99,
        'sounds': <Object?>[],
      }));

      final index = await storeOn(libDir).read();

      expect(index, isA<LocalSoundIndexOk>());
      final sounds = (index as LocalSoundIndexOk).sounds;
      expect(sounds, hasLength(1),
          reason: 'gelecekten gelen şema, diskteki sesi yok saymamalı');
      expect(sounds.single.title, 'night rain');
      expect(sounds.single.sizeBytes, 32, reason: 'boyut diskten okunmalı');
      expect(File(p.join(libDir.path, fileName)).existsSync(), isTrue);
    });
  });

  group('per-kayıt tolerans', () {
    test('ORTADAKİ kayıt bozuksa yalnızca o düşer, diğer 4 yaşar', () async {
      // "Hepsini at" politikası (arketip deposundaki) buraya KOPYALANMADI:
      // arketip testini kullanıcı yeniden çözebilir, ama 30 dosyayı tek tek
      // yeniden seçmek istemez. Tek bozuk kayıt 4 sağlamı öldürmemeli.
      final entries = <Map<String, Object?>>[
        for (var i = 0; i < 5; i++)
          sound(
            hex: '00000000000000$i$i',
            title: 'ses $i',
          ).toJson(),
      ];
      entries[2]['sizeBytes'] = 'çok'; // tip ihlali — sayı beklenirken metin

      indexFile().writeAsStringSync(jsonEncode(<String, Object?>{
        'schemaVersion': LocalSoundStore.fileSchemaVersion,
        'sounds': entries,
      }));

      final index = await storeOn(libDir).read();

      expect(index, isA<LocalSoundIndexOk>());
      final sounds = (index as LocalSoundIndexOk).sounds;
      expect(sounds, hasLength(4), reason: 'kalan 4 kayıt feda edilmemeli');
      expect(
        sounds.map((s) => s.title),
        <String>['ses 0', 'ses 1', 'ses 3', 'ses 4'],
        reason: 'düşen tam olarak bozuk olan kayıt olmalı',
      );

      // Karantina TETİKLENMEMELİ: manifest ayrıştırılabildi, yalnızca bir kayıt
      // kötüydü. Aksi hâlde her küçük kusur bir .corrupt dosyası üretirdi.
      expect(
        namesOnDisk().where((n) => n.contains('.corrupt-')),
        isEmpty,
        reason: 'tek bozuk kayıt karantina sebebi değil',
      );
    });
  });

  group('decodeFileName', () {
    test('sözleşmeye uyan ad id ve başlığa çözülür', () {
      final decoded =
          LocalSoundStore.decodeFileName('3f2a9c1b7e0d4a86__night-rain.mp3');
      expect(decoded, isNotNull);
      expect(decoded!.id, 'local-3f2a9c1b7e0d4a86');
      expect(decoded.title, 'night rain');
    });

    test('index.json, .part, .corrupt-* ve desteklenmeyen uzantı ELENİR', () {
      // Bu eleme dekoratif değil: bu adların herhangi biri geçseydi, yeniden
      // inşa manifesti "ses" sanır, uzlaştırma da onu yetim ilan ederdi.
      expect(LocalSoundStore.decodeFileName('index.json'), isNull);
      expect(
        LocalSoundStore.decodeFileName('3f2a9c1b7e0d4a86__night-rain.mp3.part'),
        isNull,
        reason: 'yarım kopya asla gerçek dosya sayılmamalı',
      );
      expect(LocalSoundStore.decodeFileName('index.json.corrupt-1784'), isNull);
      expect(
        LocalSoundStore.decodeFileName('3f2a9c1b7e0d4a86__notlar.txt'),
        isNull,
        reason: 'çalamayacağımız uzantı kütüphaneye girmemeli',
      );
      // Sözleşmeye uymayan diğer biçimler.
      expect(LocalSoundStore.decodeFileName('kisa__ses.mp3'), isNull);
      expect(
        LocalSoundStore.decodeFileName('3F2A9C1B7E0D4A86__ses.mp3'),
        isNull,
        reason: 'hex küçük harf sözleşmesi',
      );
    });
  });

  group('slugify', () {
    test('türkçe, emoji ve boşluklu ad güvenli slug üretir', () {
      // Kullanıcının HAM dosya adı diskte kullanılmaz: ayrılmış karakterler,
      // uzunluk sınırı ve '../' hepsi buradan girerdi.
      final slug = LocalSoundStore.slugify('Gece Yağmuru 🌧️ Sesi');
      expect(slug, matches(RegExp(r'^[a-z0-9-]+$')));
      expect(slug, isNot(contains(' ')));
      expect(slug, isNot(contains('/')));
      expect(slug, startsWith('gece'));
      expect(slug, endsWith('sesi'));
      // Baştaki/sondaki tireler kırpılır — '-ses-.mp3' gibi çirkin adlar olmaz.
      expect(slug, isNot(startsWith('-')));
      expect(slug, isNot(endsWith('-')));
    });

    test('tamamen elenen girdi sessizce boş kalmaz: "ses"', () {
      // Boş slug '<hex>__.mp3' üretirdi; decodeFileName bunu çözemez ve dosya
      // yeniden inşada GÖRÜNMEZ olurdu — sessiz veri kaybı.
      expect(LocalSoundStore.slugify(''), 'ses');
      expect(LocalSoundStore.slugify('🌧️🌙'), 'ses');
      expect(LocalSoundStore.slugify('---'), 'ses');
    });

    test('40 karakter sınırı aşılmaz (dosya sistemi ad sınırı)', () {
      final slug = LocalSoundStore.slugify('a' * 60);
      expect(slug.length, 40);
      expect(LocalSoundStore.slugify('kisa').length, 4,
          reason: 'sınır altındakine dokunulmamalı');
    });

    test('buildFileName sözleşmesi decodeFileName ile TERSİNİR', () {
      // İki taraf birbirinden bağımsız değişirse kurtarma sessizce ölür.
      final name = LocalSoundStore.buildFileName(
        hex: 'a1b2c3d4e5f60718',
        title: 'Gece Yagmuru',
        extension: 'm4a',
      );
      expect(name, 'a1b2c3d4e5f60718__gece-yagmuru.m4a');
      final decoded = LocalSoundStore.decodeFileName(name);
      expect(decoded, isNotNull);
      expect(decoded!.id, 'local-a1b2c3d4e5f60718');
      expect(decoded.title, 'gece yagmuru');
    });
  });
}
