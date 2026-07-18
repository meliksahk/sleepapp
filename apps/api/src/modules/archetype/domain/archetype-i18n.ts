import type { Locale } from '../../../shared/locale';
import type { QuestionMatrix } from './archetype';

/**
 * Soru matrisinin çevirileri (viral kanca #1 — kullanıcı testi KENDİ dilinde yapar).
 *
 * **TASARIM KURALI — SKORLAMA DİLDEN BAĞIMSIZDIR.** Burada yalnızca `prompt` ve
 * `label` metinleri yaşar; `id` ve `archetype` eşlemesi ASLA çevrilmez. Skorlama
 * yalnızca id'lere bakar, dolayısıyla Türkçe test eden bir kullanıcı ile İngilizce
 * test eden kullanıcı aynı cevaplarda aynı sonucu alır. Bu, test edilen bir
 * değişmezdir (bkz. archetype-i18n.spec.ts) — çeviriye yeni bir dil eklemek
 * skorlamayı bozamaz.
 *
 * **Eksik çeviri = İngilizce metin** (sessiz düşüş): yeni bir soru eklenip çevirisi
 * unutulursa kullanıcı İngilizce görür ama test ÇALIŞMAYA DEVAM EDER. Boş metin
 * göstermek veya patlamak, kullanıcı için çok daha kötü olurdu.
 *
 * SAĞLIK İDDİASI YASAK (CLAUDE.md §1.1): metinler "rahatlama ve uyku ritüeli"
 * dilinde; tedavi/terapi/iyileştirme ifadesi yok.
 */
interface QuestionStrings {
  readonly prompt: string;
  readonly options: Readonly<Record<string, string>>;
}

const TR_MATRIX_V1: Readonly<Record<string, QuestionStrings>> = {
  q1: {
    prompt: 'Başını yastığa koyduğunda zihnin…',
    options: {
      q1a: 'durulup dibe çöker',
      q1b: 'bütün günü baştan oynatır',
      q1c: 'uzaklarda bir yerlere süzülür',
      q1d: 'çoktan yarını planlıyordur',
    },
  },
  q2: {
    prompt: 'Yatak odandaki ideal ses…',
    options: {
      q2a: 'derin okyanus sessizliği',
      q2b: 'düşüncelerimi susturan hafif yağmur',
      q2c: 'ağır ağır gelen ambiyans dalgaları',
      q2d: 'hiçbir şey — güneşle uyanırım',
    },
  },
  q3: {
    prompt: 'Gece 3’te uyandın. Sen…',
    options: {
      q3a: 'dönüp yeniden dalarsın',
      q3b: 'kafanda yapılacaklar listesi kurarsın',
      q3c: 'yarı rüyada süzülürsün',
      q3d: 'sabah olmuş mu diye bakarsın',
    },
  },
  q4: {
    prompt: 'Sabahlar en iyi şöyleyken hissettirir…',
    options: {
      q4a: 'taş gibi uyumuşsam',
      q4b: 'kafam nihayet susmuşsa',
      q4c: 'canlı bir rüya hatırlıyorsam',
      q4d: 'ilk ışık beni usulca uyandırdıysa',
    },
  },
  q5: {
    prompt: 'Alarmınla ilişkin…',
    options: {
      q5a: 'ona nadiren ihtiyacım olur',
      q5b: 'uyanık yatarken onu geçerim',
      q5c: 'beni derin uykudan söker',
      q5d: 'o çalmadan ayaktayım',
    },
  },
  q6: {
    prompt: 'Kusursuz bir gece…',
    options: {
      q6a: 'derin ve rüyasızdır',
      q6b: 'nihayet kapanabilmektir',
      q6c: 'uzun, savruk, gerçeküstüdür',
      q6d: 'erken yatıp erken kalkmaktır',
    },
  },
};

const MATRIX_TRANSLATIONS: Readonly<Partial<Record<Locale, typeof TR_MATRIX_V1>>> = {
  tr: TR_MATRIX_V1,
};

/**
 * Matrisi verilen dile çevirir. `en` (veya çevirisi olmayan dil) → matris aynen döner.
 *
 * Yapı KORUNUR: aynı sorular, aynı sıra, aynı id'ler, aynı arketip eşlemesi.
 */
export function localizeMatrix(matrix: QuestionMatrix, locale: Locale): QuestionMatrix {
  const strings = MATRIX_TRANSLATIONS[locale];
  if (!strings) return matrix;

  return {
    version: matrix.version,
    questions: matrix.questions.map((q) => {
      const t = strings[q.id];
      if (!t) return q;
      return {
        id: q.id,
        prompt: t.prompt ?? q.prompt,
        options: q.options.map((o) => ({
          id: o.id,
          label: t.options[o.id] ?? o.label,
          // Arketip ASLA çevrilmez — skorlamanın dilden bağımsızlığı buna dayanır.
          archetype: o.archetype,
        })),
      };
    }),
  };
}
