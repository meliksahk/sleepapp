import { resolveLocale } from '../../../shared/locale';
import { ARCHETYPE_MATRIX_V1, scoreAnswers, type Answers } from './archetype';
import { getArchetypeInfo, listArchetypeInfo } from './archetype-content';
import { localizeMatrix } from './archetype-i18n';

describe('locale çözümü (Accept-Language)', () => {
  it('başlık yoksa/boşsa varsayılan EN', () => {
    expect(resolveLocale()).toBe('en');
    expect(resolveLocale(null)).toBe('en');
    expect(resolveLocale('')).toBe('en');
  });

  it('alt etiketi soyar: tr-TR → tr', () => {
    expect(resolveLocale('tr-TR')).toBe('tr');
    expect(resolveLocale('TR')).toBe('tr');
  });

  it('q değerlerine saygı gösterir — en yüksek kalite kazanır', () => {
    expect(resolveLocale('tr-TR,tr;q=0.9,en;q=0.8')).toBe('tr');
    expect(resolveLocale('en;q=0.9,tr;q=0.3')).toBe('en');
    // Desteklenmeyen dil en yüksek olsa bile atlanır (fr yok → tr seçilir).
    expect(resolveLocale('fr;q=1.0,tr;q=0.5')).toBe('tr');
  });

  it('q=0 "bu dili istemiyorum" demektir → elenir', () => {
    expect(resolveLocale('tr;q=0,en;q=0.5')).toBe('en');
  });

  it('desteklenmeyen veya bozuk başlık → EN (istek KIRILMAZ)', () => {
    expect(resolveLocale('de,fr;q=0.8')).toBe('en');
    expect(resolveLocale(';;;')).toBe('en');
    expect(resolveLocale('tr;q=abc')).toBe('tr'); // bozuk q → 1 sayılır
  });
});

describe('matris çevirisi', () => {
  const en = ARCHETYPE_MATRIX_V1;
  const tr = localizeMatrix(en, 'tr');

  it('EN istenirse matris AYNEN döner (kimlik)', () => {
    expect(localizeMatrix(en, 'en')).toBe(en);
  });

  it('TR metinleri gerçekten çevrilmiş', () => {
    expect(tr.questions[0]?.prompt).toBe('Başını yastığa koyduğunda zihnin…');
    expect(tr.questions[0]?.options[0]?.label).toBe('durulup dibe çöker');
    // Regresyon: hiçbir TR metni İngilizce kalmamalı.
    for (const q of tr.questions) {
      expect(q.prompt).not.toBe(en.questions.find((e) => e.id === q.id)?.prompt);
    }
  });

  /**
   * BU TESTİN KORUDUĞU ŞEY: skorlama dilden bağımsızdır. Çeviri yapısı bozarsa
   * (id kayması, seçenek sırası, arketip değişimi) test kırılır — yani yeni bir
   * dil eklemek asla bir kullanıcının sonucunu değiştiremez.
   */
  it('YAPI KORUNUR: aynı sürüm, aynı id ve arketip eşlemesi', () => {
    expect(tr.version).toBe(en.version);
    expect(tr.questions.map((q) => q.id)).toEqual(en.questions.map((q) => q.id));
    for (const [i, q] of tr.questions.entries()) {
      const original = en.questions[i]!;
      expect(q.options.map((o) => o.id)).toEqual(original.options.map((o) => o.id));
      expect(q.options.map((o) => o.archetype)).toEqual(original.options.map((o) => o.archetype));
    }
  });

  it('SKORLAMA DİLDEN BAĞIMSIZ: aynı cevaplar → aynı sonuç', () => {
    const answers: Answers = Object.fromEntries(
      en.questions.map((q, i) => [q.id, q.options[i % q.options.length]!.id]),
    );
    expect(scoreAnswers(tr, answers)).toEqual(scoreAnswers(en, answers));
  });

  it('çevirisi olmayan soru İngilizce kalır (sessiz düşüş, patlamaz)', () => {
    const withExtra = {
      version: 1,
      questions: [
        ...en.questions,
        {
          id: 'q99',
          prompt: 'Untranslated?',
          options: [{ id: 'q99a', label: 'yes', archetype: 'deep-ocean' as const }],
        },
      ],
    };
    const out = localizeMatrix(withExtra, 'tr');
    expect(out.questions.at(-1)?.prompt).toBe('Untranslated?');
    expect(out.questions[0]?.prompt).toBe('Başını yastığa koyduğunda zihnin…');
  });
});

describe('tanıtım içeriği çevirisi', () => {
  it('TR anlatım çevrilir ama İSİM korunur (marka/paylaşım tanınırlığı)', () => {
    const en = getArchetypeInfo('deep-ocean', 'en')!;
    const tr = getArchetypeInfo('deep-ocean', 'tr')!;
    expect(tr.name).toBe(en.name);
    expect(tr.name).toBe('Deep Ocean');
    expect(tr.tagline).not.toBe(en.tagline);
    expect(tr.tagline).toContain('yastığa');
  });

  it('dil verilmezse EN; bilinmeyen slug undefined', () => {
    expect(getArchetypeInfo('deep-ocean')?.tagline).toBe(
      getArchetypeInfo('deep-ocean', 'en')?.tagline,
    );
    expect(getArchetypeInfo('yok-boyle-bir-sey', 'tr')).toBeUndefined();
  });

  it('TÜM arketiplerin TR içeriği tam (eksik çeviri regresyonu)', () => {
    const tr = listArchetypeInfo('tr');
    const en = listArchetypeInfo('en');
    expect(tr).toHaveLength(en.length);
    for (const [i, info] of tr.entries()) {
      expect(info.tagline).not.toBe(en[i]!.tagline);
      expect(info.summary).not.toBe(en[i]!.summary);
    }
  });

  it('SAĞLIK İDDİASI YOK (CLAUDE.md §1.1) — TR metinlerde de', () => {
    const forbidden = /tedavi|terapi|iyileştir|şifa|hastalık|ilaç|kür/i;
    for (const info of listArchetypeInfo('tr')) {
      expect(`${info.tagline} ${info.summary}`).not.toMatch(forbidden);
    }
    for (const q of localizeMatrix(ARCHETYPE_MATRIX_V1, 'tr').questions) {
      expect(q.prompt).not.toMatch(forbidden);
      for (const o of q.options) expect(o.label).not.toMatch(forbidden);
    }
  });
});
