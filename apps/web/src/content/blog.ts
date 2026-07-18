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

const MORE_POSTS: readonly BlogPost[] = [
  {
    slug: 'setting-up-sound-in-your-bedroom',
    title: 'Setting Up Sound in Your Bedroom',
    description:
      'A few small choices — where the sound comes from, how loud it is, and when it starts — make a bedroom soundscape feel calm instead of distracting.',
    publishedAt: '2026-07-17',
    readingMinutes: 4,
    intro:
      'A good bedroom soundscape is easy to get slightly wrong: too loud, too bright, or started too late. The fixes are small and mostly about placement and habit, not gear.',
    sections: [
      {
        heading: 'Let the sound come from low and far',
        paragraphs: [
          'Sound that sits low in the room and slightly away from your head feels more like an environment and less like a device talking at you. A speaker across the room usually beats a phone on the pillow.',
          'If a phone is all you have, that is fine — just turn the screen away and set it face down so light does not leak into the room.',
        ],
      },
      {
        heading: 'Keep it quieter than you think',
        paragraphs: [
          'The goal is a floor of steady sound you stop noticing, not something you actively listen to. Set it just loud enough to soften the edges of the room, then leave it there.',
        ],
      },
      {
        heading: 'Start it before you need it',
        paragraphs: [
          'Begin the soundscape a little before you lie down, so it is already part of the room when your mind starts to settle. Starting it after you are already restless makes it feel like a fix rather than a background.',
          'The NOCTA mixer lets you set a blend once and reuse it every night, so the setup becomes part of the ritual instead of a nightly decision.',
        ],
      },
    ],
  },
  {
    slug: 'layering-soundscapes',
    title: 'How to Layer Soundscapes for a Fuller Night',
    description:
      'Layering means blending two or three simple sounds — like rain over a low drone — into one texture that feels richer than any single layer alone.',
    publishedAt: '2026-07-11',
    readingMinutes: 4,
    intro:
      'A single sound can feel thin after a while. Layering a few simple textures together gives you something fuller and more natural, without becoming busy enough to hold your attention.',
    sections: [
      {
        heading: 'Start with a base',
        paragraphs: [
          'Begin with one low, continuous layer — brown noise or a soft drone — as the floor of the mix. This is the part that fills the room and covers sudden changes from outside.',
        ],
      },
      {
        heading: 'Add one character layer',
        paragraphs: [
          'On top of the base, add a single layer with some character: gentle rain, distant water, or soft wind. One is usually enough. Two character layers tend to compete, and the mix starts to sound busy.',
        ],
      },
      {
        heading: 'Balance, then leave it',
        paragraphs: [
          'Bring the character layer up until you can just hear it over the base, then stop. The best sleep mix is one you notice for a moment and then forget.',
          'The NOCTA mixer runs each layer independently, so you can nudge one without restarting the others — blend once, and it stays yours.',
        ],
      },
    ],
  },
  {
    slug: 'consistent-bedtime',
    title: 'Why a Consistent Bedtime Makes a Ritual Stick',
    description:
      'A consistent bedtime gives the rest of your evening ritual something to attach to, so the small steps start happening on their own.',
    publishedAt: '2026-07-08',
    readingMinutes: 3,
    intro:
      'Evening rituals fall apart when the finish line keeps moving. A roughly consistent bedtime is the anchor that makes every other small step easier to keep.',
    sections: [
      {
        heading: 'The anchor does the work',
        paragraphs: [
          'When bedtime lands around the same time most nights, your wind-down steps have somewhere to attach. The cutoff, the dimmed lights, the soundscape — they all line up behind a fixed point instead of floating loose.',
        ],
      },
      {
        heading: 'Aim for a window, not a stopwatch',
        paragraphs: [
          'Consistency does not mean the exact same minute every night. A thirty-minute window is enough for your evening to find its rhythm, and it survives the occasional late night without collapsing.',
        ],
      },
      {
        heading: 'Let the rhythm you have guide you',
        paragraphs: [
          'The right window depends on your natural rhythm — an early riser and a night owl should not force the same bedtime. The free sleep identity test is a quick way to find the window that already fits you.',
        ],
      },
    ],
  },
];

export const BLOG_POSTS_ALL: readonly BlogPost[] = [...BLOG_POSTS, ...MORE_POSTS];

export const BLOG_SLUGS: readonly string[] = BLOG_POSTS_ALL.map((p) => p.slug);

export function getBlogPost(slug: string): BlogPost | undefined {
  return BLOG_POSTS_ALL.find((p) => p.slug === slug);
}

/** En yeniden eskiye — dizin sayfası sıralaması. */
export function blogPostsNewestFirst(): readonly BlogPost[] {
  return [...BLOG_POSTS_ALL].sort((a, b) => b.publishedAt.localeCompare(a.publishedAt));
}
