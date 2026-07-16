import type { Metadata } from 'next';
import './globals.css';
import { SiteFooter } from '@/components/SiteFooter';
import { buildOrganizationJsonLd, buildWebSiteJsonLd } from '@/lib/schema';

export const metadata: Metadata = {
  title: 'NOCTA — Your night has an identity',
  description: 'A sleep ritual app built around sleep identity.',
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
