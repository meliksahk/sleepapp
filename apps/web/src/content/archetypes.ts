// Archetype içerik verisi — /a/{slug} sayfaları (docs/05 SEO/GEO). Tek kaynak.
// SAĞLIK İDDİASI YASAK (CLAUDE.md §1.1): cure/treat/therapy vb. yok — "relaxation & sleep ritual".

export interface ArchetypeContent {
  readonly slug: string;
  readonly name: string;
  readonly tagline: string;
  /** Kısa, alıntılanabilir tanım (GEO — ilk cümlede doğrudan cevap). */
  readonly summary: string;
  readonly paragraphs: readonly string[];
  /** "Bu kimliğe iyi gelen sesler" — ritüel dili, iddia değil. */
  readonly soundsThatHelp: readonly string[];
}

export const ARCHETYPES: readonly ArchetypeContent[] = [
  {
    slug: 'deep-ocean',
    name: 'Deep Ocean',
    tagline: 'You sink into stillness the moment your head hits the pillow.',
    summary:
      'The Deep Ocean sleeper drops into deep, quiet rest quickly and rarely stirs before morning.',
    paragraphs: [
      'If you are a Deep Ocean sleeper, sleep tends to arrive easily. Your mind settles, the day lets go, and you slip beneath the surface into steady, uninterrupted rest.',
      'This does not mean every night is perfect. Travel, stress, or a noisy room can still ripple the water. A calm, low, enveloping soundscape helps you protect the stillness you naturally reach for.',
      'Build a simple night ritual: dim light, one slow sound layer, and a consistent bedtime. Deep Ocean sleepers thrive on rhythm, not intensity.',
    ],
    soundsThatHelp: ['Deep ocean hush', 'Brown noise', 'Slow low drones'],
  },
  {
    slug: 'overthinker',
    name: '3AM Overthinker',
    tagline: 'Your body is tired, but your mind is still writing tomorrow’s list.',
    summary:
      'The Overthinker lies awake replaying the day; a gentle, masking soundscape helps quiet the mental chatter.',
    paragraphs: [
      'If you are an Overthinker, falling asleep is less about tiredness and more about switching off. The lights go out and your thoughts get louder — the day’s conversations, tomorrow’s plans, the small worries.',
      'A soft, continuous sound gives your attention something calm to rest on, so the loop has less room to run. Rain and gentle texture work well because they are steady without being interesting.',
      'A wind-down ritual matters most for you: a fixed cutoff for screens, a few slow breaths, and a sound that starts before your mind speeds up.',
    ],
    soundsThatHelp: ['Soft rain', 'Pink noise', 'Distant thunder'],
  },
  {
    slug: 'delta-drifter',
    name: 'Delta Drifter',
    tagline: 'You float through long, vivid, half-dream nights.',
    summary:
      'The Delta Drifter drifts through deep, dream-rich sleep and can feel groggy when woken mid-cycle.',
    paragraphs: [
      'If you are a Delta Drifter, your nights run long and layered. You reach deep sleep readily and often wake with fragments of vivid dreams.',
      'The trick for you is the wake, not the fall. Being pulled out of a deep cycle by a harsh alarm leaves you foggy. A slow, rising soundscape that eases you toward morning fits your rhythm better.',
      'Lean into ambient, flowing layers at night and a gentle sunrise-style wind-up in the morning.',
    ],
    soundsThatHelp: ['Ambient waves', 'Slow pads', 'Flowing water'],
  },
  {
    slug: 'dawn-chaser',
    name: 'Dawn Chaser',
    tagline: 'You are wired to rise with the first light.',
    summary:
      'The Dawn Chaser wakes early and naturally; a quiet, minimal night and a bright morning suit this rhythm.',
    paragraphs: [
      'If you are a Dawn Chaser, mornings are your territory. You often wake before the alarm and feel most yourself in the early hours.',
      'Your challenge is the evening: winding down early enough to protect that early start. A minimal, low-stimulation night ritual helps you fall asleep sooner rather than later.',
      'Keep nights simple and quiet, and let a bright, gentle morning cue reinforce the rhythm your body already prefers.',
    ],
    soundsThatHelp: ['Quiet warmth', 'Minimal drone', 'Soft morning birds'],
  },
];

export const ARCHETYPE_SLUGS: readonly string[] = ARCHETYPES.map((a) => a.slug);

export function getArchetype(slug: string): ArchetypeContent | undefined {
  return ARCHETYPES.find((a) => a.slug === slug);
}
