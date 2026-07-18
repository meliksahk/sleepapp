/// Arketip matrisi ve puanlama — **saf Dart** (CLAUDE.md §3.1: `domain/` hiçbir
/// Flutter/IO paketi import etmez).
///
/// ## NEDEN CİHAZDA
///
/// Arketip testi (viral kanca #1) tamamen sunucudaydı: sorular sunucudan,
/// puanlama sunucuda, sonuç sunucudan. Backend ayakta değilken kurulan bir APK'da
/// kanca ÖLÜYDU — kullanıcı "Kimliğini keşfet"e basıyor, hata görüyordu.
///
/// ## NEDEN ELLE KOPYALANMADI
///
/// Matris `assets/archetype/matrix.json`'dan okunur; o dosya sunucunun domain'inden
/// ÜRETİLİR (`tooling/gen-archetype-matrix.mjs`) ve bir drift kapısıyla kilitlenir
/// (`tooling/check-archetype-drift.mjs`). Elle kopyalasaydık iki uygulama sessizce
/// ayrışırdı: sunucuya bir soru eklenir, cihaz eski matriste kalır, AYNI cevaplar
/// FARKLI arketip üretirdi.
///
/// ## ALGORİTMA — SUNUCUNUN AYNISI
///
/// Kaynak: `apps/api/src/modules/archetype/domain/archetype.ts#scoreAnswers`.
/// Her cevaplanan soru, seçilen seçeneğin arketipine +1 verir. Kazanan:
/// [ArchetypeMatrix.archetypes] sırasında gezilir ve yalnızca **kesin büyük**
/// (`>`, `>=` DEĞİL) skor kazananı değiştirir. Yani **beraberlikte listede önce
/// gelen kazanır** — bu, iki uygulamanın en kolay ayrışacağı yerdir ve üretilen
/// JSON'daki doğrulama vektörleriyle test altındadır (64 vektörün 34'ü beraberlik).
library;

/// Bir sorunun tek seçeneği. `label` YOK: metin dile göre ayrı yaşar
/// ([ArchetypeMatrix.promptFor] / [ArchetypeMatrix.optionLabel]) çünkü skorlama
/// dilden bağımsızdır — TR test eden ile EN test eden aynı cevaplarda aynı sonucu
/// alır (sunucudaki tasarım kuralının aynısı, archetype-i18n.ts).
class ArchetypeOptionDef {
  const ArchetypeOptionDef({required this.id, required this.archetype});

  final String id;
  final String archetype;
}

class ArchetypeQuestionDef {
  const ArchetypeQuestionDef({required this.id, required this.options});

  final String id;
  final List<ArchetypeOptionDef> options;
}

/// Bir arketipin tanıtım metni (isim/tagline/özet), tek dilde.
class ArchetypeText {
  const ArchetypeText({
    required this.name,
    required this.tagline,
    required this.summary,
  });

  final String name;
  final String tagline;
  final String summary;
}

/// Puanlama sonucu — sunucunun `ScoreResult`'ının Dart karşılığı.
class ArchetypeScore {
  const ArchetypeScore({required this.archetypeSlug, required this.scores});

  final String archetypeSlug;

  /// Tüm arketipler için skor (0 dahil) — sunucu da 0'ları gönderir.
  final Map<String, int> scores;
}

/// Üretilen `matrix.json`'un Dart görünümü.
class ArchetypeMatrix {
  /// Yalnızca [ArchetypeMatrix.fromJson] üzerinden kurulur: matris ÜRETİLEN bir
  /// dosyadan gelir, elle kurulan bir matris sunucudan sapma riskidir.
  /// Konumsal parametreler bilinçli: `_questionText` gibi PRIVATE alanlar Dart'ta
  /// isimli parametre olamaz, ama konumsal `this._x` olabilir. Alanları public
  /// yapmak ise private `_QuestionText` tipini public API'ye sızdırırdı.
  const ArchetypeMatrix._(
    this.version,
    this.archetypes,
    this.locales,
    this.questions,
    this._questionText,
    this._archetypeText,
  );

  final int version;

  /// Arketip slug'ları — **SIRA ANLAMLIDIR** (beraberlik kuralı buna dayanır).
  final List<String> archetypes;

  final List<String> locales;
  final List<ArchetypeQuestionDef> questions;

  /// locale → questionId → metinler.
  final Map<String, Map<String, _QuestionText>> _questionText;

  /// locale → slug → tanıtım metni.
  final Map<String, Map<String, ArchetypeText>> _archetypeText;

  /// Çevirisi olmayan dil için düşülecek dil (sunucu ile aynı: EN birincil).
  static const String fallbackLocale = 'en';

  factory ArchetypeMatrix.fromJson(Map<String, dynamic> json) {
    final questions = <ArchetypeQuestionDef>[
      for (final q in json['questions'] as List<dynamic>)
        ArchetypeQuestionDef(
          id: (q as Map<String, dynamic>)['id'] as String,
          options: <ArchetypeOptionDef>[
            for (final o in q['options'] as List<dynamic>)
              ArchetypeOptionDef(
                id: (o as Map<String, dynamic>)['id'] as String,
                archetype: o['archetype'] as String,
              ),
          ],
        ),
    ];

    final questionText = <String, Map<String, _QuestionText>>{};
    final archetypeText = <String, Map<String, ArchetypeText>>{};
    final text = json['text'] as Map<String, dynamic>;
    for (final entry in text.entries) {
      final block = entry.value as Map<String, dynamic>;
      final localeQuestions = <String, _QuestionText>{};
      for (final q in (block['questions'] as Map<String, dynamic>).entries) {
        final value = q.value as Map<String, dynamic>;
        localeQuestions[q.key] = _QuestionText(
          prompt: value['prompt'] as String,
          options: (value['options'] as Map<String, dynamic>)
              .map((k, v) => MapEntry(k, v as String)),
        );
      }
      questionText[entry.key] = localeQuestions;
      archetypeText[entry.key] = <String, ArchetypeText>{
        for (final a in (block['archetypes'] as Map<String, dynamic>).entries)
          a.key: ArchetypeText(
            name: (a.value as Map<String, dynamic>)['name'] as String,
            tagline: (a.value as Map<String, dynamic>)['tagline'] as String,
            summary: (a.value as Map<String, dynamic>)['summary'] as String,
          ),
      };
    }

    return ArchetypeMatrix._(
      json['version'] as int,
      <String>[for (final a in json['archetypes'] as List<dynamic>) a as String],
      <String>[for (final l in json['locales'] as List<dynamic>) l as String],
      questions,
      questionText,
      archetypeText,
    );
  }

  /// Verilen dilde soru metni. Çeviri yoksa EN'e düşer — **sessiz düşüş
  /// bilinçli**: yeni bir soru eklenip çevirisi unutulursa kullanıcı İngilizce
  /// görür ama test ÇALIŞMAYA DEVAM EDER (sunucudaki kuralın aynısı).
  String promptFor(String questionId, String locale) {
    return _questionText[locale]?[questionId]?.prompt ??
        _questionText[fallbackLocale]?[questionId]?.prompt ??
        questionId;
  }

  String optionLabel(String questionId, String optionId, String locale) {
    return _questionText[locale]?[questionId]?.options[optionId] ??
        _questionText[fallbackLocale]?[questionId]?.options[optionId] ??
        optionId;
  }

  /// Verilen dilde tüm arketiplerin tanıtım metni (slug → metin).
  Map<String, ArchetypeText> textsFor(String locale) {
    return _archetypeText[locale] ?? _archetypeText[fallbackLocale] ?? const {};
  }

  /// Cevapların eksiksiz ve geçerli olduğunu doğrular; sorun yoksa null.
  /// Sunucudaki `findInvalidAnswer` ile aynı sözleşme (`missing:` / `invalid:`).
  String? findInvalidAnswer(Map<String, String> answers) {
    for (final q in questions) {
      final chosen = answers[q.id];
      if (chosen == null) return 'missing:${q.id}';
      if (!q.options.any((o) => o.id == chosen)) return 'invalid:${q.id}';
    }
    return null;
  }

  /// Cevaplar → kazanan arketip + skorlar.
  ///
  /// Sunucunun `scoreAnswers`'ının BİREBİR karşılığı. Beraberlikte
  /// [archetypes] sırasında önce gelen kazanır (`>` karşılaştırması).
  ArchetypeScore scoreAnswers(Map<String, String> answers) {
    final scores = <String, int>{for (final slug in archetypes) slug: 0};

    for (final q in questions) {
      final chosen = answers[q.id];
      // Cevaplanmamış/bilinmeyen soru sessizce atlanır — sunucu da öyle yapar
      // (doğrulama ayrı bir adım: findInvalidAnswer).
      for (final o in q.options) {
        if (o.id == chosen) {
          scores[o.archetype] = (scores[o.archetype] ?? 0) + 1;
          break;
        }
      }
    }

    var winner = archetypes.first;
    for (final slug in archetypes) {
      if ((scores[slug] ?? 0) > (scores[winner] ?? 0)) winner = slug;
    }
    return ArchetypeScore(archetypeSlug: winner, scores: scores);
  }
}

class _QuestionText {
  const _QuestionText({required this.prompt, required this.options});

  final String prompt;
  final Map<String, String> options;
}
