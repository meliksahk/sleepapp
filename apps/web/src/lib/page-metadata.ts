import type { Metadata } from 'next';
import { t, type Locale } from '@/lib/i18n';
import { buildAlternates, localePath, SITE_URL } from '@/lib/routes';

/**
 * Sayfa metadata'sı — EN ve TR rota dosyaları AYNI üreticiyi kullanır.
 *
 * **Neden `alternates` kök layout'ta DEĞİL:** Next metadata'yı ağaçta aşağı doğru
 * birleştirir. Kök layout'a canonical koysaydık, kendi `alternates`'ini set etmeyen
 * her sayfa (ör. blog) yanlışlıkla ANA SAYFANIN canonical'ını miras alırdı — sessiz
 * ve ciddi bir SEO kırığı. Bu yüzden canonical/hreflang sayfa başına verilir.
 */

/** Kök layout metadata'sı (dil başına). OG/twitter varsayılanları burada yaşar. */
export function buildRootMetadata(locale: Locale): Metadata {
  const title = t(locale, 'meta.site.title');
  const description = t(locale, 'meta.site.description');
  return {
    // KRİTİK: bu olmadan Next tüm og:image / twitter:image URL'lerini localhost:3000'e
    // çözer → sayfa paylaşılınca önizleme kartı KIRIK olur (viral zincirin sessiz kırığı).
    metadataBase: new URL(SITE_URL),
    title,
    description,
    openGraph: {
      type: 'website',
      siteName: 'NOCTA',
      locale: locale === 'tr' ? 'tr_TR' : 'en_US',
      // DİLE GÖRE: og:url paylaşılan nesnenin KİMLİĞİdir (Facebook/LinkedIn/WhatsApp
      // beğeni ve paylaşım sayısını buna göre birleştirir). Sabit SITE_URL bırakılsaydı
      // TR sayfaların paylaşımları İngilizce ana sayfaya konsolide olur ve önizlemede
      // yanlış dil çıkardı — canonical/hreflang doğruyken sosyal katman kırıktı.
      url: `${SITE_URL}${localePath(locale, '/')}`,
      title,
      description,
    },
    // Büyük kart: bu olmadan Twitter küçük thumbnail gösterir → OG görselleri
    // paylaşımda tam boy çıkmaz.
    twitter: { card: 'summary_large_image' },
  };
}

export function buildHomeMetadata(locale: Locale): Metadata {
  return {
    alternates: buildAlternates(locale, '/'),
    openGraph: {
      title: t(locale, 'meta.home.ogTitle'),
      url: `${SITE_URL}${localePath(locale, '/')}`,
    },
  };
}

export function buildTestMetadata(locale: Locale): Metadata {
  return {
    title: t(locale, 'meta.test.title'),
    description: t(locale, 'meta.test.description'),
    alternates: buildAlternates(locale, '/test'),
  };
}

export function buildArchetypesMetadata(locale: Locale): Metadata {
  return {
    title: t(locale, 'meta.archetypes.title'),
    description: t(locale, 'meta.archetypes.description'),
    alternates: buildAlternates(locale, '/archetypes'),
    openGraph: {
      title: t(locale, 'meta.archetypes.ogTitle'),
      description: t(locale, 'meta.archetypes.ogDescription'),
    },
  };
}

export function buildFaqMetadata(locale: Locale): Metadata {
  return {
    title: t(locale, 'meta.faq.title'),
    description: t(locale, 'meta.faq.description'),
    alternates: buildAlternates(locale, '/faq'),
    openGraph: {
      title: t(locale, 'meta.faq.ogTitle'),
      description: t(locale, 'meta.faq.ogDescription'),
    },
  };
}

export function buildArchetypeMetadata(
  locale: Locale,
  archetype: { slug: string; name: string; summary: string },
): Metadata {
  return {
    title: t(locale, 'meta.archetype.title', { name: archetype.name }),
    description: archetype.summary,
    alternates: buildAlternates(locale, `/a/${archetype.slug}`),
    openGraph: {
      title: t(locale, 'meta.archetype.ogTitle', { name: archetype.name }),
      description: archetype.summary,
    },
  };
}
