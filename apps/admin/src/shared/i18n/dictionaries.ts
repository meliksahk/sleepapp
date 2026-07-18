/**
 * Admin panel sözlükleri.
 *
 * **Neden çerez tabanlı, neden URL'de `[locale]` YOK:** admin bir İÇ ARAÇ — SEO,
 * paylaşılabilir çok-dilli URL, arama motoru indekslemesi gerekmiyor. `[locale]`
 * segment refactor'ü tüm route'ları, linkleri ve testleri değiştirirdi; kazancı
 * sıfır, riski yüksek olurdu. Dil çerezde tutulur, layout okur, sağlayıcı dağıtır.
 *
 * **Neden tek dosyada tipli sözlük:** anahtar seti TypeScript'te sabitlenir →
 * EN'de olup TR'de olmayan bir anahtar DERLEME HATASI verir. Mobilde bu güvenceyi
 * ayrı bir parity testi sağlıyordu; burada tip sistemi bedavaya veriyor.
 */
export const dictionaries = {
  tr: {
    'nav.dashboard': 'Pano',
    'nav.campaigns': 'Kampanyalar',
    'nav.security': 'Güvenlik',
    'lang.label': 'Dil',
    'lang.tr': 'Türkçe',
    'lang.en': 'English',

    'campaign.title': 'Push kampanyası',
    'campaign.fieldTitle': 'Başlık',
    'campaign.fieldBody': 'Mesaj',
    'campaign.fieldPlatform': 'Hedef',
    'campaign.platformAll': 'Tümü',
    'campaign.submit': 'Kampanyayı gönder',
    'campaign.submitting': 'Gönderiliyor…',
    'campaign.queued':
      'Kuyruğa alındı: {recipients} kullanıcı segmentte, {queued} teslim işi sıraya kondu. Teslim arka planda yapılıyor.',
    'campaign.errorForbidden': 'Bu işlem için yetkiniz yok.',
    'campaign.errorGeneric': 'Gönderilemedi. Lütfen tekrar deneyin.',
  },
  en: {
    'nav.dashboard': 'Dashboard',
    'nav.campaigns': 'Campaigns',
    'nav.security': 'Security',
    'lang.label': 'Language',
    'lang.tr': 'Türkçe',
    'lang.en': 'English',

    'campaign.title': 'Push campaign',
    'campaign.fieldTitle': 'Title',
    'campaign.fieldBody': 'Message',
    'campaign.fieldPlatform': 'Target',
    'campaign.platformAll': 'All',
    'campaign.submit': 'Send campaign',
    'campaign.submitting': 'Sending…',
    'campaign.queued':
      'Queued: {recipients} users in segment, {queued} delivery jobs enqueued. Delivery happens in the background.',
    'campaign.errorForbidden': 'You do not have permission for this action.',
    'campaign.errorGeneric': 'Could not send. Please try again.',
  },
} as const;

export type Locale = keyof typeof dictionaries;
export type MessageKey = keyof (typeof dictionaries)['tr'];

export const locales: readonly Locale[] = ['tr', 'en'] as const;

/** Varsayılan TR: panel bugüne dek Türkçeydi, mevcut kullanıcı deneyimi korunur. */
export const defaultLocale: Locale = 'tr';

export function isLocale(value: string | undefined): value is Locale {
  return value === 'tr' || value === 'en';
}

/** `{ad}` yer tutucularını doldurur. Eksik değer anahtarı OLDUĞU GİBİ bırakır. */
export function translate(
  locale: Locale,
  key: MessageKey,
  vars?: Record<string, string | number>,
): string {
  const raw: string = dictionaries[locale][key];
  if (!vars) return raw;
  return raw.replace(/\{(\w+)\}/g, (match, name: string) =>
    name in vars ? String(vars[name]) : match,
  );
}
