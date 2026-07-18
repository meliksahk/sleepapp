/**
 * Tanıtım sitesi sözlükleri (EN birincil, TR ikincil — CLAUDE.md §4).
 *
 * **Neden `/tr/` alt dizini, neden `[locale]` segmenti YOK:** site SEO/GEO odaklı;
 * her dilin AYRI indekslenebilir bir URL'i olmalı (admin'in çerez çözümü burada
 * çalışmaz). `[locale]` segmenti aynı SEO sonucunu verirdi ama mevcut EN rotalarının
 * tamamını, OG rotalarını ve test dosyalarındaki href kilitlerini kırardı. `/tr/`
 * paralel rota grubu aynı hreflang/canonical zincirini kurar, EN tarafına dokunmaz.
 *
 * **Neden tek dosyada tipli sözlük:** anahtar seti TypeScript'te sabitlenir →
 * EN'de olup TR'de olmayan bir anahtar DERLEME HATASI verir (admin'deki
 * `shared/i18n/dictionaries.ts` deseninin aynısı).
 *
 * Sağlık iddiası YASAK (CLAUDE.md §1.1): her iki dilde de konumlandırma
 * "rahatlama ve uyku ritüeli" / "relaxation & sleep ritual".
 */

export const LOCALES = ['en', 'tr'] as const;
export type Locale = (typeof LOCALES)[number];
export const DEFAULT_LOCALE: Locale = 'en';

export function isLocale(value: string | undefined): value is Locale {
  return value === 'en' || value === 'tr';
}

const en = {
  // — Ana sayfa —
  'home.title': 'Your night has an identity.',
  'home.intro':
    'NOCTA is a sleep ritual app. Discover your sleep identity, then build a night that fits it.',
  'home.cta': 'Find your sleep identity',
  'home.waitlistHeading': 'Join the waitlist',
  'home.waitlistIntro': 'Be first to know when NOCTA launches.',

  // — Bekleme listesi formu —
  'waitlist.emailLabel': 'Email',
  'waitlist.emailPlaceholder': 'you@example.com',
  'waitlist.submit': 'Join',
  'waitlist.success': 'Thanks — you are on the list. We will let you know at launch.',
  'waitlist.error': 'Something went wrong. Please try again.',

  // — Test sayfası —
  'test.h1': 'What’s your sleep identity?',
  'test.intro': 'Six quick questions. No account needed.',
  'test.loading': 'Loading…',
  'test.errorQuestions': 'Could not load the questions.',
  'test.errorSubmit': 'Could not work out your result.',
  'test.submit': 'See your result',
  'test.submitting': 'Working it out…',
  'test.resultLabel': 'Your sleep identity',
  'test.readMore': 'Read about your archetype',

  // — Paylaşım kartı (viral kanca) —
  'card.save': 'Save your card',
  'card.preparing': 'Preparing…',
  'card.saved': 'Card saved.',
  'card.error': 'Could not create the image. Try again.',
  'card.previewAlt': '{name} share card preview',
  'card.eyebrow': 'SLEEP IDENTITY',
  'card.soundsHeading': 'Sounds that suit you',
  'card.shareTitle': 'My sleep identity is {name}',

  // — Paylaş butonu —
  'share.action': 'Share this identity',
  'share.copied': 'Link copied',

  // — Archetype sayfası —
  'archetype.eyebrow': 'Sleep Identity',
  'archetype.soundsHeading': 'Sounds that suit you',
  'archetype.ctaTest': 'Take the sleep identity test',
  'archetype.shareRegion': 'Shareable card',
  'archetype.shareHeading': 'Share your identity',
  'archetype.shareIntro': 'Save a 9:16 card for stories.',
  'archetype.othersHeading': 'Other sleep identities',

  // — Archetype dizini —
  'archetypes.eyebrow': 'Sleep Identities',
  'archetypes.h1': 'Which one are you?',
  'archetypes.intro':
    'Every sleeper has a rhythm. Explore the identities, then take the test to find yours.',
  'archetypes.listName': 'Sleep identities',

  // — SSS —
  'faq.eyebrow': 'Questions',
  'faq.h1': 'Frequently asked',

  // — Footer —
  'footer.nav': 'Footer',
  'footer.identities': 'Sleep identities',
  'footer.test': 'Take the test',
  'footer.faq': 'FAQ',
  'footer.tagline': 'NOCTA — a relaxation and sleep ritual. © 2026',
  'footer.otherLocale': 'Türkçe',

  // — Gezinti kırıntısı adları (JSON-LD) —
  'crumb.home': 'Home',

  // — Meta (title/description) —
  'meta.site.title': 'NOCTA — Your night has an identity',
  'meta.site.description': 'A sleep ritual app built around sleep identity.',
  'meta.home.ogTitle': 'NOCTA — Your night has an identity',
  'meta.test.title': 'Sleep Archetype Test — NOCTA',
  'meta.test.description': 'Find your sleep identity in 60 seconds.',
  'meta.archetypes.title': 'Sleep Identities — All Archetypes | NOCTA',
  'meta.archetypes.description':
    'Explore every NOCTA sleep identity. Find the one that fits your nights and the sounds that suit it.',
  'meta.archetypes.ogTitle': 'Sleep Identities — All Archetypes',
  'meta.archetypes.ogDescription':
    'Explore every NOCTA sleep identity and the sounds that suit it.',
  'meta.faq.title': 'FAQ — NOCTA Sleep Ritual',
  'meta.faq.description':
    'Answers about NOCTA: what a sleep identity is, the free tier, offline sound engine, privacy, and shareable cards.',
  'meta.faq.ogTitle': 'NOCTA FAQ',
  'meta.faq.ogDescription':
    'What NOCTA is, how the sleep identity test works, pricing, offline use, and privacy.',
  'meta.archetype.title': '{name} — Your Sleep Identity | NOCTA',
  'meta.archetype.ogTitle': '{name} — Your Sleep Identity',
  'meta.archetype.headline': '{name} — Sleep Identity',
} as const;

export type MessageKey = keyof typeof en;

const tr: Record<MessageKey, string> = {
  // — Ana sayfa —
  'home.title': 'Gecenin bir kimliği var.',
  'home.intro':
    'NOCTA bir uyku ritüeli uygulaması. Uyku kimliğini keşfet, sonra ona göre bir gece kur.',
  'home.cta': 'Uyku kimliğini bul',
  'home.waitlistHeading': 'Bekleme listesine katıl',
  'home.waitlistIntro': 'NOCTA çıktığında ilk sen haberdar ol.',

  // — Bekleme listesi formu —
  'waitlist.emailLabel': 'E-posta',
  'waitlist.emailPlaceholder': 'sen@ornek.com',
  'waitlist.submit': 'Katıl',
  'waitlist.success': 'Teşekkürler — listedesin. Lansmanda haber vereceğiz.',
  'waitlist.error': 'Bir şeyler ters gitti. Lütfen tekrar dene.',

  // — Test sayfası —
  'test.h1': 'Uyku kimliğin ne?',
  'test.intro': 'Altı kısa soru. Hesap açmana gerek yok.',
  'test.loading': 'Yükleniyor…',
  'test.errorQuestions': 'Sorular yüklenemedi.',
  'test.errorSubmit': 'Sonuç hesaplanamadı.',
  'test.submit': 'Sonucu gör',
  'test.submitting': 'Hesaplanıyor…',
  'test.resultLabel': 'Uyku kimliğin',
  'test.readMore': 'Arketipin hakkında oku',

  // — Paylaşım kartı (viral kanca) —
  'card.save': 'Kartını kaydet',
  'card.preparing': 'Hazırlanıyor…',
  'card.saved': 'Kart kaydedildi.',
  'card.error': 'Görsel oluşturulamadı. Tekrar dene.',
  'card.previewAlt': '{name} paylaşım kartı önizlemesi',
  'card.eyebrow': 'UYKU KİMLİĞİ',
  'card.soundsHeading': 'Sana uyan sesler',
  'card.shareTitle': 'Uyku kimliğim: {name}',

  // — Paylaş butonu —
  'share.action': 'Bu kimliği paylaş',
  'share.copied': 'Bağlantı kopyalandı',

  // — Archetype sayfası —
  'archetype.eyebrow': 'Uyku Kimliği',
  'archetype.soundsHeading': 'Sana uyan sesler',
  'archetype.ctaTest': 'Uyku kimliği testini çöz',
  'archetype.shareRegion': 'Paylaşılabilir kart',
  'archetype.shareHeading': 'Kimliğini paylaş',
  'archetype.shareIntro': 'Hikâyeler için 9:16 kart indir.',
  'archetype.othersHeading': 'Diğer uyku kimlikleri',

  // — Archetype dizini —
  'archetypes.eyebrow': 'Uyku Kimlikleri',
  'archetypes.h1': 'Hangisisin?',
  'archetypes.intro':
    'Her uyuyanın bir ritmi var. Kimlikleri incele, sonra testi çözüp kendininkini bul.',
  'archetypes.listName': 'Uyku kimlikleri',

  // — SSS —
  'faq.eyebrow': 'Sorular',
  'faq.h1': 'Sık sorulanlar',

  // — Footer —
  'footer.nav': 'Alt bilgi',
  'footer.identities': 'Uyku kimlikleri',
  'footer.test': 'Testi çöz',
  'footer.faq': 'SSS',
  'footer.tagline': 'NOCTA — rahatlama ve uyku ritüeli. © 2026',
  'footer.otherLocale': 'English',

  // — Gezinti kırıntısı adları (JSON-LD) —
  'crumb.home': 'Ana sayfa',

  // — Meta (title/description) —
  'meta.site.title': 'NOCTA — Gecenin bir kimliği var',
  'meta.site.description': 'Uyku kimliği üzerine kurulu bir uyku ritüeli uygulaması.',
  'meta.home.ogTitle': 'NOCTA — Gecenin bir kimliği var',
  'meta.test.title': 'Uyku Arketipi Testi — NOCTA',
  'meta.test.description': '60 saniyede uyku kimliğini bul.',
  'meta.archetypes.title': 'Uyku Kimlikleri — Tüm Arketipler | NOCTA',
  'meta.archetypes.description':
    'NOCTA’nın bütün uyku kimliklerini keşfet. Gecelerine uyanı ve ona yakışan sesleri bul.',
  'meta.archetypes.ogTitle': 'Uyku Kimlikleri — Tüm Arketipler',
  'meta.archetypes.ogDescription':
    'NOCTA’nın bütün uyku kimliklerini ve her birine yakışan sesleri keşfet.',
  'meta.faq.title': 'SSS — NOCTA Uyku Ritüeli',
  'meta.faq.description':
    'NOCTA hakkında yanıtlar: uyku kimliği nedir, ücretsiz katman, çevrimdışı ses motoru, gizlilik ve paylaşılabilir kartlar.',
  'meta.faq.ogTitle': 'NOCTA SSS',
  'meta.faq.ogDescription':
    'NOCTA nedir, uyku kimliği testi nasıl çalışır, fiyatlandırma, çevrimdışı kullanım ve gizlilik.',
  'meta.archetype.title': '{name} — Uyku Kimliğin | NOCTA',
  'meta.archetype.ogTitle': '{name} — Uyku Kimliğin',
  'meta.archetype.headline': '{name} — Uyku Kimliği',
};

export const dictionaries: Record<Locale, Record<MessageKey, string>> = { en, tr };

/** `{ad}` yer tutucularını doldurur. Eksik değer anahtarı OLDUĞU GİBİ bırakır. */
export function t(locale: Locale, key: MessageKey, vars?: Record<string, string | number>): string {
  const raw = dictionaries[locale][key];
  if (!vars) return raw;
  return raw.replace(/\{(\w+)\}/g, (match, name: string) =>
    name in vars ? String(vars[name]) : match,
  );
}
