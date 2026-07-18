import type { Metadata } from 'next';
import './globals.css';
import { SiteFooter } from '@/components/SiteFooter';
import { SITE_URL } from '@/lib/routes';
import { buildOrganizationJsonLd, buildWebSiteJsonLd } from '@/lib/schema';

const TITLE = 'NOCTA — Your night has an identity';
const DESCRIPTION = 'A sleep ritual app built around sleep identity.';

export const metadata: Metadata = {
  // KRİTİK: bu olmadan Next tüm og:image / twitter:image URL'lerini localhost:3000'e
  // çözer → sayfa paylaşılınca önizleme kartı KIRIK (opengraph-image.tsx dosyaları #176/#182
  // yerelde geçerli PNG üretse de, meta'daki mutlak URL yanlış olurdu). Bu, viral zincirin
  // (docs/05) sessiz kırığıydı — build de uyarıyordu.
  metadataBase: new URL(SITE_URL),
  title: TITLE,
  description: DESCRIPTION,
  // Site geneli OG/Twitter varsayılanları. Sayfalar kendi openGraph.title/description'ını
  // set edince Next bunları alan-bazında birleştirir (siteName/type miras kalır) —
  // ampirik olarak üretilen HTML'de doğrulandı (blog og:title korunuyor).
  openGraph: {
    type: 'website',
    siteName: 'NOCTA',
    url: SITE_URL,
    title: TITLE,
    description: DESCRIPTION,
  },
  // Büyük kart: bu olmadan Twitter küçük thumbnail gösterir → #176/#182 OG görselleri
  // paylaşımda tam boy çıkmazdı.
  twitter: { card: 'summary_large_image' },
};

// Site geneli JSON-LD (Organization + WebSite) — tek util'den, her sayfada.
const siteJsonLd = [buildOrganizationJsonLd(), buildWebSiteJsonLd()];

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(siteJsonLd) }}
        />
        {children}
        <SiteFooter />
      </body>
    </html>
  );
}
