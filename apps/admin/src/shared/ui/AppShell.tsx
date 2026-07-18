'use client';

import type { ReactNode } from 'react';
import Link from 'next/link';
import { LocaleSwitcher } from '../i18n/LocaleSwitcher';
import type { MessageKey } from '../i18n/dictionaries';
import { useT } from '../i18n/I18nProvider';

// Mevcut route → link; henüz yapılmamışlar (href yok) sönük span kalır (B3).
/** Navigasyon: etiketler ARTIK anahtar (dile göre çözülür). Nav İngilizce,
 * gövde Türkçeydi — panel karışık dildeydi; bu onu da düzeltir.
 *
 * `nav.security` sözlükte vardı ama HİÇBİR YERE bağlı değildi: /security sayfası
 * mevcut ama panelde ona giden tek bir link yoktu (yalnızca URL'i elle yazarak
 * ulaşılıyordu). Ölü anahtarı silmek yerine eksik linki eklemek doğru düzeltme. */
const NAV: ReadonlyArray<{ key: MessageKey; href?: string }> = [
  { key: 'nav.dashboard', href: '/' },
  { key: 'nav.content', href: '/content' },
  { key: 'nav.users', href: '/users' },
  { key: 'nav.analytics' },
  { key: 'nav.flags', href: '/flags' },
  { key: 'nav.campaigns', href: '/campaigns' },
  { key: 'nav.security', href: '/security' },
];

/**
 * Panel iskeleti: sidebar + topbar + içerik (docs/03 A0). Rol-guard'lı navigasyon B3'te.
 *
 * `actions`: topbar'a konacak eylemler (ör. çıkış). SLOT olarak alınır çünkü AppShell
 * `shared` katmanındadır ve `features`'ı import EDEMEZ (boundary lint). Bileşeni
 * kimin geçireceğine app katmanı karar verir — bağımlılık yönü korunur.
 */
export function AppShell({ children, actions }: { children: ReactNode; actions?: ReactNode }) {
  const t = useT();
  return (
    <div className="flex min-h-screen bg-bg-base text-ink-primary">
      <aside className="w-56 shrink-0 border-r border-ink-faint/20 p-4">
        <p className="text-h2 font-display">NOCTA</p>
        <nav className="mt-6 flex flex-col gap-1">
          {NAV.map((item) =>
            item.href ? (
              <Link
                key={t(item.key)}
                href={item.href}
                className="rounded-chip px-3 py-2 text-body text-ink-primary hover:bg-ink-faint/10"
              >
                {t(item.key)}
              </Link>
            ) : (
              <span
                key={t(item.key)}
                className="rounded-chip px-3 py-2 text-body text-ink-secondary/50"
              >
                {t(item.key)}
              </span>
            ),
          )}
        </nav>
      </aside>
      <div className="flex-1">
        <header className="flex items-center justify-between border-b border-ink-faint/20 px-6 py-4">
          <h1 className="text-h2 font-display">{t('common.admin')}</h1>
          <div className="flex items-center gap-4">
            <LocaleSwitcher />
            {actions}
          </div>
        </header>
        <main className="p-6">{children}</main>
      </div>
    </div>
  );
}
