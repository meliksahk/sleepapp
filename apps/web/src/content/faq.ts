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
