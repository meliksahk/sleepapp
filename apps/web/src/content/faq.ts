// SSS içeriği — GEO/SEO için alıntılanabilir soru-cevap (docs/05 §4).
// SAĞLIK İDDİASI YASAK (CLAUDE.md §1.1): "relaxation & sleep ritual" dili;
// sonuç/tedavi iddiası yok — yalnızca özellik ve deneyim anlatılır.

export interface FaqItem {
  readonly question: string;
  readonly answer: string;
}

export const FAQ_ITEMS: readonly FaqItem[] = [
  {
    question: 'What is NOCTA?',
    answer:
      'NOCTA is a relaxation and sleep ritual app built around your sleep identity. It pairs a personalized soundscape engine and mixer with a calming nightly wind-down routine.',
  },
  {
    question: 'What is a sleep identity?',
    answer:
      'A sleep identity — or archetype — is a playful profile of how you tend to wind down at night. A short test matches you to one and suggests the soundscapes that suit your rhythm.',
  },
  {
    question: 'Is NOCTA free?',
    answer:
      'Yes. NOCTA has a generous free tier with the core sound engine and mixer. A premium tier adds extra soundscapes and export features, with a real 7-day trial.',
  },
  {
    question: 'Does NOCTA work offline?',
    answer:
      'Yes. The generative sound engine and mixer run fully on your device, so you can build and play your mixes without an internet connection.',
  },
  {
    question: 'Does NOCTA record my microphone?',
    answer:
      'Sleep tracking analysis happens on your device. Only derived metrics — such as movement and sound event counts — are ever sent to our servers. Raw audio never leaves your phone.',
  },
  {
    question: 'What can I share from NOCTA?',
    answer:
      'After the test or a night, NOCTA can create a shareable card that summarizes your sleep identity or your night, designed to look good on social feeds.',
  },
];

/**
 * Türkçe SSS (/tr/faq) — FAQPage JSON-LD'si de bu içerikten üretilir.
 * Sağlık iddiası YASAK (CLAUDE.md §1.1): yalnızca özellik ve deneyim anlatılır.
 */
export const FAQ_ITEMS_TR: readonly FaqItem[] = [
  {
    question: 'NOCTA nedir?',
    answer:
      'NOCTA, uyku kimliğin üzerine kurulu bir rahatlama ve uyku ritüeli uygulamasıdır. Kişiselleştirilmiş bir ses motorunu ve mikseri sakin bir gece rutiniyle birleştirir.',
  },
  {
    question: 'Uyku kimliği nedir?',
    answer:
      'Uyku kimliği — ya da arketip — geceleri nasıl yavaşladığını anlatan keyifli bir profildir. Kısa bir test seni bunlardan birine eşler ve ritmine uyan ses dokularını önerir.',
  },
  {
    question: 'NOCTA ücretsiz mi?',
    answer:
      'Evet. Çekirdek ses motorunu ve mikseri kapsayan cömert bir ücretsiz katman var. Premium katman ek ses dokuları ve dışa aktarma özellikleri ekler; gerçek 7 günlük deneme ile birlikte.',
  },
  {
    question: 'NOCTA çevrimdışı çalışır mı?',
    answer:
      'Evet. Jeneratif ses motoru ve mikser tamamen cihazında çalışır; miksleri internet bağlantısı olmadan kurup çalabilirsin.',
  },
  {
    question: 'NOCTA mikrofonumu kaydediyor mu?',
    answer:
      'Uyku takibi analizi cihazının içinde yapılır. Sunucularımıza yalnızca türetilmiş ölçümler — örneğin hareket ve ses olayı sayıları — gider. Ham ses telefonundan hiç çıkmaz.',
  },
  {
    question: 'NOCTA’dan ne paylaşabilirim?',
    answer:
      'Testten sonra ya da bir gecenin ardından NOCTA, uyku kimliğini veya geceni özetleyen paylaşılabilir bir kart üretebilir; sosyal akışlarda iyi görünecek şekilde tasarlanmıştır.',
  },
];

export const FAQ_BY_LOCALE = {
  en: FAQ_ITEMS,
  tr: FAQ_ITEMS_TR,
} as const;

export function getFaqItems(locale: 'en' | 'tr'): readonly FaqItem[] {
  return FAQ_BY_LOCALE[locale];
}
