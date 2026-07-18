import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import { SUPPORTED_LOCALES, type Locale } from '../../../shared/locale';
import {
  ARCHETYPES,
  ARCHETYPE_MATRIX_V1,
  scoreAnswers,
  type Answers,
  type ArchetypeSlug,
} from './archetype';
import { listArchetypeInfo } from './archetype-content';
import { localizeMatrix } from './archetype-i18n';

/**
 * # SUNUCU ↔ CİHAZ EŞDEĞERLİĞİ — sunucu tarafındaki yarısı
 *
 * `apps/mobile/assets/archetype/matrix.json` bu domain'den ÜRETİLİR
 * (`tooling/gen-archetype-matrix.mjs`) ve mobil uygulama arketip testini onunla,
 * BACKEND OLMADAN koşar. Yani o dosya artık bir kopya değil, ikinci bir
 * uygulamanın çalışan kaynağı.
 *
 * Buradaki testler şunu kilitler: dosyadaki yapı, metinler ve gömülü beklenen
 * çıktılar sunucunun BUGÜNKÜ davranışıyla hâlâ aynı. Dart tarafı aynı dosyadaki
 * aynı vektörleri kendi puanlamasıyla doğrular
 * (`test/features/archetype/archetype_matrix_test.dart`), `check-archetype-drift.mjs`
 * ise dosyanın kaynaktan bayt bayt üretilmiş olduğunu garanti eder.
 *
 * Üçü olmadan "aynı sonucu veriyorlar" bir temenniydi; üçüyle test edilen bir olgu.
 *
 * **Bu test kırıldığında yapılacak şey `pnpm gen:archetype`** — matris değişti ama
 * cihazın kopyası güncellenmedi demektir.
 */

interface ExportedMatrix {
  version: number;
  archetypes: ArchetypeSlug[];
  locales: Locale[];
  questions: { id: string; options: { id: string; archetype: ArchetypeSlug }[] }[];
  text: Record<
    string,
    {
      questions: Record<string, { prompt: string; options: Record<string, string> }>;
      archetypes: Record<string, { name: string; tagline: string; summary: string }>;
    }
  >;
  vectors: {
    answers: Record<string, string>;
    archetypeSlug: ArchetypeSlug;
    scores: Record<ArchetypeSlug, number>;
  }[];
}

const EXPORT_PATH = join(__dirname, '../../../../../../apps/mobile/assets/archetype/matrix.json');

describe('arketip matrisi dışa aktarımı (mobil gömülü kopya)', () => {
  let exported: ExportedMatrix;

  beforeAll(() => {
    exported = JSON.parse(readFileSync(EXPORT_PATH, 'utf8')) as ExportedMatrix;
  });

  it('sürüm, arketipler ve diller sunucu ile aynı', () => {
    expect(exported.version).toBe(ARCHETYPE_MATRIX_V1.version);
    expect(exported.archetypes).toEqual([...ARCHETYPES]);
    expect(exported.locales).toEqual([...SUPPORTED_LOCALES]);
  });

  it("soru YAPISI birebir aynı (id'ler, sıra, arketip eşlemesi)", () => {
    expect(exported.questions).toEqual(
      ARCHETYPE_MATRIX_V1.questions.map((q) => ({
        id: q.id,
        options: q.options.map((o) => ({ id: o.id, archetype: o.archetype })),
      })),
    );
  });

  it.each([...SUPPORTED_LOCALES])('%s metinleri sunucudakiyle aynı', (locale) => {
    const localized = localizeMatrix(ARCHETYPE_MATRIX_V1, locale);
    for (const q of localized.questions) {
      const block = exported.text[locale]?.questions[q.id];
      expect(block?.prompt).toBe(q.prompt);
      for (const o of q.options) {
        expect(block?.options[o.id]).toBe(o.label);
      }
    }

    for (const info of listArchetypeInfo(locale)) {
      expect(exported.text[locale]?.archetypes[info.slug]).toEqual({
        name: info.name,
        tagline: info.tagline,
        summary: info.summary,
      });
    }
  });

  it('EŞDEĞERLİK: gömülü vektörler sunucunun scoreAnswers çıktısıyla aynı', () => {
    expect(exported.vectors.length).toBeGreaterThan(0);

    for (const [i, vector] of exported.vectors.entries()) {
      const actual = scoreAnswers(ARCHETYPE_MATRIX_V1, vector.answers as Answers);
      expect({ index: i, ...actual }).toEqual({
        index: i,
        archetypeSlug: vector.archetypeSlug,
        scores: vector.scores,
      });
    }
  });

  it('vektörler BERABERLİK durumlarını kapsıyor (kural gerçekten test ediliyor)', () => {
    // Beraberlik, iki uygulamanın en kolay ayrışacağı yer: TS'te kural
    // "ARCHETYPES sırasında ilk gelen kazanır" (`>` karşılaştırması).
    const ties = exported.vectors.filter((v) => {
      const values = Object.values(v.scores);
      const max = Math.max(...values);
      return values.filter((s) => s === max).length > 1;
    });
    expect(ties.length).toBeGreaterThan(exported.vectors.length / 4);
  });

  it('her vektör TAM ve GEÇERLİ bir cevap kümesi (yarım vektör bir şey kanıtlamaz)', () => {
    for (const vector of exported.vectors) {
      expect(Object.keys(vector.answers).sort()).toEqual(
        ARCHETYPE_MATRIX_V1.questions.map((q) => q.id).sort(),
      );
    }
  });
});
