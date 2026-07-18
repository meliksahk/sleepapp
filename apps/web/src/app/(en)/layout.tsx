import type { Metadata } from 'next';
import '../globals.css';
import { RootShell } from '@/components/RootShell';
import { buildRootMetadata } from '@/lib/page-metadata';

/**
 * EN kök layout.
 *
 * `(en)` bir ROTA GRUBUDUR — URL'e hiçbir şey eklemez; `/`, `/test`, `/a/...`,
 * `/sitemap.xml` adresleri birebir korunur. Grup yalnızca TR'nin kendi
 * `<html lang="tr">` kök layout'una sahip olabilmesi için var (bkz. RootShell).
 *
 * metadataBase + Twitter büyük kart kararları `lib/page-metadata.ts`'e taşındı;
 * gerekçeleri (localhost'a çözülen og:image, küçük thumbnail) orada belgeli.
 */
export const metadata: Metadata = buildRootMetadata('en');

export default function EnRootLayout({ children }: { children: React.ReactNode }) {
  return <RootShell locale="en">{children}</RootShell>;
}
