import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/features/archetype/data/archetype_matrix_source.dart';
import 'package:nocta/features/archetype/domain/archetype_matrix.dart';

/// # EŞDEĞERLİK TESTİ — cihaz puanlaması SUNUCU puanlamasıyla aynı mı?
///
/// ## Nasıl kanıtlanıyor (yöntem)
///
/// `assets/archetype/matrix.json` sunucunun domain'inden ÜRETİLİR
/// (`tooling/gen-archetype-matrix.mjs`) ve üretim sırasında sunucunun KENDİ
/// `scoreAnswers` fonksiyonu 64 cevap kümesi üzerinde koşturulup beklenen
/// çıktılar dosyaya gömülür (`vectors`).
///
/// - **Burada (Dart):** aynı cevaplarla CİHAZ puanlaması koşulur ve gömülü
///   çıktılarla karşılaştırılır.
/// - **Sunucu tarafında (`archetype-matrix-export.spec.ts`):** aynı dosya okunur
///   ve gömülü çıktıların sunucunun BUGÜNKÜ `scoreAnswers`'ıyla hâlâ uyuştuğu
///   doğrulanır.
/// - **Drift kapısı (`check-archetype-drift.mjs`):** dosyanın kaynağıyla bayt
///   bayt aynı olduğunu garanti eder.
///
/// Üçü birlikte şunu verir: iki uygulama aynı cevaplara aynı arketibi ve aynı
/// skorları üretir, ve biri değişirse CI kırılır. Tek bir "aynı olduğuna
/// inanıyorum" adımı yok.
///
/// ## Neden vektörlerin yarısından fazlası BERABERLİK
///
/// İki uygulamanın en kolay ayrışacağı yer beraberlik kuralıdır (TS'te
/// "ARCHETYPES sırasında ilk gelen kazanır", `>` karşılaştırması). 64 vektörün
/// 34'ü beraberlik üretiyor — kural yanlış portlansaydı burada patlardı.
void main() {
  late Map<String, dynamic> raw;
  late ArchetypeMatrix matrix;

  setUpAll(() async {
    raw = jsonDecode(File(archetypeMatrixAsset).readAsStringSync())
        as Map<String, dynamic>;
    matrix = ArchetypeMatrix.fromJson(raw);
  });

  test('üretilen matris asset olarak mevcut ve ayrıştırılabiliyor', () {
    expect(File(archetypeMatrixAsset).existsSync(), isTrue,
        reason: '$archetypeMatrixAsset yok — pnpm gen:archetype koşuldu mu?');
    expect(matrix.questions, isNotEmpty);
    expect(matrix.archetypes.length, 4);
    expect(matrix.locales, containsAll(<String>['en', 'tr']));
  });

  test('EŞDEĞERLİK: her doğrulama vektöründe Dart puanlaması sunucununkiyle aynı',
      () {
    final vectors = raw['vectors'] as List<dynamic>;
    expect(vectors, isNotEmpty, reason: 'vektörsüz eşdeğerlik iddiası boştur');

    for (var i = 0; i < vectors.length; i++) {
      final v = vectors[i] as Map<String, dynamic>;
      final answers = (v['answers'] as Map<String, dynamic>)
          .map((k, value) => MapEntry(k, value as String));
      final expectedSlug = v['archetypeSlug'] as String;
      final expectedScores = (v['scores'] as Map<String, dynamic>)
          .map((k, value) => MapEntry(k, value as int));

      final actual = matrix.scoreAnswers(answers);

      expect(actual.archetypeSlug, expectedSlug,
          reason: 'vektör #$i — cevaplar: $answers');
      expect(actual.scores, expectedScores, reason: 'vektör #$i skorları');
    }
  });

  test('vektörlerin anlamlı bir kısmı BERABERLİK içeriyor (kural gerçekten test ediliyor)',
      () {
    final vectors = raw['vectors'] as List<dynamic>;
    var ties = 0;
    for (final v in vectors) {
      final scores = ((v as Map<String, dynamic>)['scores'] as Map<String, dynamic>)
          .values
          .cast<int>()
          .toList();
      final max = scores.reduce((a, b) => a > b ? a : b);
      if (scores.where((s) => s == max).length > 1) ties++;
    }
    expect(ties, greaterThan(vectors.length ~/ 4),
        reason: 'beraberlik kuralı kapsanmıyorsa eşdeğerlik testi zayıftır');
  });

  test('beraberlikte listede ÖNCE gelen arketip kazanır (sunucu kuralı)', () {
    // İlk yarısı 'a' (deep-ocean), ikinci yarısı 'd' (dawn-chaser) → 3-3.
    final answers = <String, String>{};
    for (var i = 0; i < matrix.questions.length; i++) {
      final q = matrix.questions[i];
      answers[q.id] = i < matrix.questions.length ~/ 2
          ? q.options.first.id
          : q.options.last.id;
    }
    final scored = matrix.scoreAnswers(answers);
    expect(scored.scores['deep-ocean'], scored.scores['dawn-chaser'],
        reason: 'test kurgusu beraberlik üretmeli');
    expect(scored.archetypeSlug, matrix.archetypes.first);
  });

  test('eksik/geçersiz cevap yakalanır (sunucunun findInvalidAnswer sözleşmesi)',
      () {
    expect(matrix.findInvalidAnswer(const <String, String>{}),
        'missing:${matrix.questions.first.id}');

    final full = <String, String>{
      for (final q in matrix.questions) q.id: q.options.first.id,
    };
    expect(matrix.findInvalidAnswer(full), isNull);

    final bad = Map<String, String>.from(full)
      ..[matrix.questions.first.id] = 'yok-boyle-bir-secenek';
    expect(matrix.findInvalidAnswer(bad), 'invalid:${matrix.questions.first.id}');
  });

  test('metinler dile göre değişir, YAPI değişmez (skorlama dilden bağımsız)', () {
    final q = matrix.questions.first;
    final en = matrix.promptFor(q.id, 'en');
    final tr = matrix.promptFor(q.id, 'tr');
    expect(en, isNotEmpty);
    expect(tr, isNotEmpty);
    expect(tr, isNot(en), reason: 'TR çevirisi gelmiyorsa i18n kırık');

    // Aynı cevaplar, dil ne olursa olsun aynı sonucu verir — çünkü puanlama
    // yalnızca id'lere bakar (sunucudaki archetype-i18n.ts tasarım kuralı).
    final answers = <String, String>{
      for (final question in matrix.questions) question.id: question.options.first.id,
    };
    expect(matrix.scoreAnswers(answers).archetypeSlug, 'deep-ocean');
  });

  test('bilinmeyen dil sessizce EN\'e düşer (boş metin gösterme)', () {
    final q = matrix.questions.first;
    expect(matrix.promptFor(q.id, 'de'), matrix.promptFor(q.id, 'en'));
    expect(matrix.textsFor('de')['deep-ocean']?.name, 'Deep Ocean');
  });

  test('TR arketip İSİMLERİ çevrilmez (marka etiketi), anlatım çevrilir', () {
    final en = matrix.textsFor('en')['deep-ocean']!;
    final tr = matrix.textsFor('tr')['deep-ocean']!;
    expect(tr.name, en.name);
    expect(tr.tagline, isNot(en.tagline));
  });
}
