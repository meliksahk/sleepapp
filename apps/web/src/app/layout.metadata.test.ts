import { describe, it, expect } from 'vitest';
import { metadata as enMetadata } from './(en)/layout';
import { metadata as trMetadata } from './(tr)/layout';
import { SITE_URL } from '@/lib/routes';

/**
 * OG/paylaşım regresyon kilidi — HER İKİ kök layout için.
 *
 * metadataBase olmadan Next tüm og:image / twitter:image URL'lerini localhost:3000'e
 * çözer → sayfa paylaşılınca önizleme kartı kırık çıkar (opengraph-image.tsx dosyaları
 * #176/#182 geçerli PNG üretse bile). Bu sessiz kırık bir kez yaşandı; bu testler
 * metadataBase + büyük Twitter kartının kaybolmasını imkânsız kılar.
 *
 * TR eklenirken ikinci bir kök layout doğdu; kilit ona da uygulanır, yoksa TR tarafı
 * aynı kırığı sessizce yeniden yaşayabilirdi.
 */
describe.each([
  ['en', enMetadata],
  ['tr', trMetadata],
])('root layout metadata — %s (OG paylaşım kilidi)', (_locale, metadata) => {
  it('metadataBase gerçek siteye ayarlı (og:image localhost DEĞİL)', () => {
    expect(metadata.metadataBase).toBeInstanceOf(URL);
    expect(metadata.metadataBase?.href).toContain('nocta.app');
    expect(metadata.metadataBase?.origin).toBe(SITE_URL);
  });

  it('site geneli OG varsayılanları (siteName + website tipi)', () => {
    const og = metadata.openGraph as { siteName?: string; type?: string } | undefined;
    expect(og?.siteName).toBe('NOCTA');
    expect(og?.type).toBe('website');
  });

  it('Twitter büyük kart (küçük thumbnail değil — OG görseli tam boy çıksın)', () => {
    const tw = metadata.twitter as { card?: string } | undefined;
    expect(tw?.card).toBe('summary_large_image');
  });

  it('kök layout canonical/hreflang TAŞIMAZ (sayfalar miras alıp yanlış canonical almasın)', () => {
    // Kritik: layout'a canonical konursa blog gibi kendi alternates'ini set etmeyen
    // sayfalar ana sayfanın canonical'ını miras alır → sessiz SEO kırığı.
    expect(metadata.alternates).toBeUndefined();
  });
});
