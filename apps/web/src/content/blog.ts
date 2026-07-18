// Blog içeriği — dosya tabanlı, tek kaynak (docs/05 SEO/GEO long-tail).
// SAĞLIK İDDİASI YASAK (CLAUDE.md §1.1): cure/treat/therapy/clinical/medical yok.
// Konumlandırma: "relaxation & sleep ritual". Her metin `pnpm check:health-claims` kapısından geçer.
//
// NEDEN TS objesi, MDX değil: `archetypes.ts` deseniyle tutarlı, yeni bağımlılık yok
// (§8 maliyet disiplini), tam tip-güvenli ve `blog.test.ts` ile yapısal doğrulanabilir.
// Blog yazıları düz nesir; başlık+paragraf yapısı yeter. Zengin biçim gerekirse MDX
// sonradan eklenebilir — ilk dilimde indekslenebilir İÇERİĞİ ship etmek önce gelir.

export interface BlogSection {
  readonly heading: string;
  readonly paragraphs: readonly string[];
}

export interface BlogPost {
  readonly slug: string;
  readonly title: string;
  /** Meta description + GEO özeti (ilk cümlede doğrudan cevap). */
  readonly description: string;
  /** ISO 8601 tarih (UTC) — Article JSON-LD datePublished. */
  readonly publishedAt: string;
  readonly readingMinutes: number;
  readonly intro: string;
  readonly sections: readonly BlogSection[];
}

export const BLOG_POSTS: readonly BlogPost[] = [
  {
    slug: 'wind-down-ritual',
    title: 'How to Build a Wind-Down Ritual',
    description:
      'A wind-down ritual is a short, repeatable set of calming steps you do before bed so your mind learns that the day is ending.',
    publishedAt: '2026-07-10',
    readingMinutes: 4,
    intro:
      'Most nights do not fall apart at bedtime — they fall apart in the hour before it. A wind-down ritual is a simple, repeatable sequence that tells your body the day is over. It is not about willpower; it is about giving your evening a shape you can follow without thinking.',
    sections: [
      {
        heading: 'Pick a fixed cutoff',
        paragraphs: [
          'Choose a time when the day’s work stops — messages, planning, screens that ask something of you. The exact hour matters less than keeping it the same every night. A steady cutoff is the single most reliable cue you can give yourself.',
          'If a hard stop feels impossible, start with a soft one: ten minutes earlier than usual, held for a week, then earlier again.',
        ],
      },
      {
        heading: 'Lower the inputs',
        paragraphs: [
          'Dim the lights, close the tabs, and let the room get quieter and warmer. The goal is fewer things asking for your attention, not a perfect spa setup. A calm, low, continuous soundscape can replace the silence that your mind tends to fill with tomorrow’s list.',
        ],
      },
      {
        heading: 'Repeat the same small steps',
        paragraphs: [
          'A ritual works because it is boring in the best way: the same three or four steps, in the same order, most nights. Over time the sequence itself becomes the signal, and you stop having to decide.',
          'Not sure where to start? Your sleep identity is a good anchor — take the free test and build the ritual around the rhythm you already have.',
        ],
      },
    ],
  },
  {
    slug: 'soundscapes-explained',
    title: 'White, Pink, and Brown Noise, Explained',
    description:
      'White, pink, and brown noise differ in how their energy is spread across frequencies — which is why each one feels different at bedtime.',
    publishedAt: '2026-07-13',
    readingMinutes: 5,
    intro:
      'People reach for a steady sound at night because a continuous texture gives attention something calm to rest on. But “noise” is not one thing. White, pink, and brown noise are shaped differently, and the difference is easy to hear once you know what to listen for.',
    sections: [
      {
        heading: 'White noise: even and bright',
        paragraphs: [
          'White noise spreads equal energy across every frequency, which makes it sound bright and full — closer to radio static or a fan on high. It is even and unchanging, which some people find masks a noisy room well.',
        ],
      },
      {
        heading: 'Pink noise: softer and balanced',
        paragraphs: [
          'Pink noise lowers the higher frequencies, so it sounds softer and rounder than white — more like steady rain than static. Many people find it easier to leave on for a long stretch because it is less harsh at the top end.',
        ],
      },
      {
        heading: 'Brown noise: deep and enveloping',
        paragraphs: [
          'Brown noise rolls off the highs even more, leaving a deep, low rumble — closer to distant surf or a waterfall heard from far away. It feels enveloping, which is why people who want something heavier tend to prefer it.',
          'There is no single “best” one. The right texture depends on your room and your rhythm — the same reason our mixer lets you blend layers rather than picking for you.',
        ],
      },
    ],
  },
  {
    slug: 'what-is-a-sleep-identity',
    title: 'What Is a Sleep Identity?',
    description:
      'A sleep identity is a simple way of describing your natural night rhythm — how you fall asleep, how deeply you rest, and how you wake.',
    publishedAt: '2026-07-16',
    readingMinutes: 4,
    intro:
      'Advice about nights usually assumes everyone is the same. They are not. A sleep identity is a plain-language way to describe your own rhythm, so the ritual you build actually fits the way your nights already run.',
    sections: [
      {
        heading: 'Rhythm, not a rulebook',
        paragraphs: [
          'Some people drop into stillness the moment their head hits the pillow. Others lie awake with a busy mind, or drift through long, dream-rich nights, or wake naturally with the first light. None of these is better — they are just different starting points.',
          'Knowing yours means you stop fighting your rhythm and start working with it.',
        ],
      },
      {
        heading: 'Why it shapes the ritual',
        paragraphs: [
          'If your mind races at bedtime, a sound that starts before the racing does is worth more than a darker room. If you wake groggy from deep sleep, a gentle rise toward morning matters more than the fall. The identity points you at the part of the night to focus on.',
        ],
      },
      {
        heading: 'Find yours',
        paragraphs: [
          'The free sleep identity test takes a couple of minutes and gives you a starting point plus a soundscape that suits your rhythm. It is a ritual companion, not a verdict — the point is to make your evenings a little easier to repeat.',
        ],
      },
    ],
  },
];

export const BLOG_SLUGS: readonly string[] = BLOG_POSTS.map((p) => p.slug);

export function getBlogPost(slug: string): BlogPost | undefined {
  return BLOG_POSTS.find((p) => p.slug === slug);
}

/** En yeniden eskiye — dizin sayfası sıralaması. */
export function blogPostsNewestFirst(): readonly BlogPost[] {
  return [...BLOG_POSTS].sort((a, b) => b.publishedAt.localeCompare(a.publishedAt));
}
