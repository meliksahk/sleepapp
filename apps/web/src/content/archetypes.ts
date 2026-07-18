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

/**
 * Türkçe archetype içeriği (/tr/a/{slug}).
 *
 * SLUG'LAR ÇEVRİLMEZ — bilinçli karar. Slug'lar paylaşım kartlarında, derin
 * linklerde (`nocta://a/deep-ocean`) ve mobil tarafta dokümante edilmiş durumda;
 * çevirmek 301 zinciri ve kırık paylaşım linki demek olurdu. Yalnızca GÖRÜNEN
 * metin çevrilir.
 *
 * Sağlık iddiası YASAK (CLAUDE.md §1.1): tedavi/terapi/klinik/şifa dili yok —
 * konumlandırma "rahatlama ve uyku ritüeli".
 */
export const ARCHETYPES_TR: readonly ArchetypeContent[] = [
  {
    slug: 'deep-ocean',
    name: 'Derin Okyanus',
    tagline: 'Başını yastığa koyar koymaz durgunluğa gömülürsün.',
    summary:
      'Derin Okyanus uyuyanı hızla derin ve sessiz bir dinlenmeye geçer, sabaha kadar pek kıpırdamaz.',
    paragraphs: [
      'Derin Okyanus uyuyanıysan uyku sana kolay gelir. Zihnin yatışır, gün elinden bırakılır ve yüzeyin altına, kesintisiz bir dinlenmeye süzülürsün.',
      'Bu her gecenin kusursuz geçtiği anlamına gelmiyor. Yolculuk, yoğun bir gün ya da gürültülü bir oda suyu yine dalgalandırabilir. Sakin, alçak ve sarmalayan bir ses dokusu, doğal olarak aradığın o durgunluğu korumanı kolaylaştırır.',
      'Basit bir gece ritüeli kur: kısık ışık, tek bir yavaş ses katmanı ve sabit bir yatış saati. Derin Okyanus uyuyanları yoğunlukla değil, ritimle iyi gider.',
    ],
    soundsThatHelp: ['Derin okyanus uğultusu', 'Kahverengi gürültü', 'Yavaş alçak droneler'],
  },
  {
    slug: 'overthinker',
    name: 'Gece 3 Düşünürü',
    tagline: 'Bedenin yorgun ama zihnin hâlâ yarının listesini yazıyor.',
    summary:
      'Gece 3 Düşünürü günü kafasında tekrar oynatarak uyanık kalır; yumuşak, maskeleyen bir ses dokusu zihindeki gürültüyü geri plana atar.',
    paragraphs: [
      'Düşünürsen, uykuya dalmak yorgunluktan çok kapanabilmekle ilgilidir. Işıklar sönünce düşüncelerin sesi yükselir — günün konuşmaları, yarının planları, küçük endişeler.',
      'Yumuşak ve sürekli bir ses, dikkatine üzerine yaslanacağı sakin bir zemin verir; böylece döngünün koşacak yeri azalır. Yağmur ve hafif dokular iyi gider, çünkü ilgi çekmeden istikrarlıdırlar.',
      'Senin için asıl mesele yavaşlama ritüeli: ekranlara sabit bir saat sınırı, birkaç yavaş nefes ve zihnin hızlanmadan önce başlayan bir ses.',
    ],
    soundsThatHelp: ['Hafif yağmur', 'Pembe gürültü', 'Uzaktan gök gürültüsü'],
  },
  {
    slug: 'delta-drifter',
    name: 'Delta Gezgini',
    tagline: 'Uzun, canlı, yarı rüya gecelerde süzülürsün.',
    summary:
      'Delta Gezgini derin ve rüya dolu bir uykuda süzülür; döngünün ortasında uyandırıldığında kendini ağır hisseder.',
    paragraphs: [
      'Delta Gezginiysen gecelerin uzun ve katmanlıdır. Derin uykuya kolayca ulaşır, çoğu sabah canlı rüya parçalarıyla uyanırsın.',
      'Senin için püf nokta uyanış, dalış değil. Sert bir alarmla derin döngüden çekilip çıkarılmak seni sisli bırakır. Sabaha doğru yavaşça yükselen bir ses dokusu ritmine daha çok yakışır.',
      'Geceleri akışkan ambiyans katmanlarına yaslan; sabahları gün doğumu gibi yumuşak yükselen bir uyanışa.',
    ],
    soundsThatHelp: ['Ambiyans dalgalar', 'Yavaş padler', 'Akan su'],
  },
  {
    slug: 'dawn-chaser',
    name: 'Şafak Kovalayan',
    tagline: 'İlk ışıkla kalkmaya programlısın.',
    summary:
      'Şafak Kovalayan erken ve kendiliğinden uyanır; sessiz, sade bir gece ve aydınlık bir sabah bu ritme iyi oturur.',
    paragraphs: [
      'Şafak Kovalayansan sabahlar senin alanın. Çoğu zaman alarmdan önce uyanır, günün ilk saatlerinde kendini en iyi hissedersin.',
      'Zorlandığın yer akşam: o erken başlangıcı koruyacak kadar erken yavaşlayabilmek. Sade, az uyarımlı bir gece ritüeli daha geç değil, daha erken uykuya dalmanı kolaylaştırır.',
      'Geceleri basit ve sessiz tut; sabahları aydınlık, yumuşak bir işaret vücudunun zaten tercih ettiği ritmi pekiştirsin.',
    ],
    soundsThatHelp: ['Sessiz sıcaklık', 'Sade drone', 'Yumuşak sabah kuşları'],
  },
];

export const ARCHETYPES_BY_LOCALE = {
  en: ARCHETYPES,
  tr: ARCHETYPES_TR,
} as const;

export const ARCHETYPE_SLUGS: readonly string[] = ARCHETYPES.map((a) => a.slug);

export function getArchetype(slug: string): ArchetypeContent | undefined {
  return ARCHETYPES.find((a) => a.slug === slug);
}

/** Dile göre archetype listesi — slug seti her dilde AYNIDIR (parity testli). */
export function getArchetypes(locale: 'en' | 'tr'): readonly ArchetypeContent[] {
  return ARCHETYPES_BY_LOCALE[locale];
}

/** Dile göre tek archetype; bilinmeyen slug'da `undefined`. */
export function getArchetypeIn(locale: 'en' | 'tr', slug: string): ArchetypeContent | undefined {
  return ARCHETYPES_BY_LOCALE[locale].find((a) => a.slug === slug);
}
