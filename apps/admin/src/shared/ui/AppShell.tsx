import type { ReactNode } from 'react';
import Link from 'next/link';

// Mevcut route → link; henüz yapılmamışlar (href yok) sönük span kalır (B3).
const NAV: ReadonlyArray<{ label: string; href?: string }> = [
  { label: 'Dashboard', href: '/' },
  { label: 'Content', href: '/content' },
  { label: 'Users', href: '/users' },
  { label: 'Analytics' },
  { label: 'Flags' },
  { label: 'Campaigns' },
];

/**
 * Panel iskeleti: sidebar + topbar + içerik (docs/03 A0). Rol-guard'lı navigasyon B3'te.
 *
 * `actions`: topbar'a konacak eylemler (ör. çıkış). SLOT olarak alınır çünkü AppShell
 * `shared` katmanındadır ve `features`'ı import EDEMEZ (boundary lint). Bileşeni
 * kimin geçireceğine app katmanı karar verir — bağımlılık yönü korunur.
 */
export function AppShell({ children, actions }: { children: ReactNode; actions?: ReactNode }) {
  return (
    <div className="flex min-h-screen bg-bg-base text-ink-primary">
      <aside className="w-56 shrink-0 border-r border-ink-faint/20 p-4">
        <p className="text-h2 font-display">NOCTA</p>
        <nav className="mt-6 flex flex-col gap-1">
          {NAV.map((item) =>
            item.href ? (
              <Link
                key={item.label}
                href={item.href}
                className="rounded-chip px-3 py-2 text-body text-ink-primary hover:bg-ink-faint/10"
              >
                {item.label}
              </Link>
            ) : (
              <span
                key={item.label}
                className="rounded-chip px-3 py-2 text-body text-ink-secondary/50"
              >
                {item.label}
              </span>
            ),
          )}
        </nav>
      </aside>
      <div className="flex-1">
        <header className="flex items-center justify-between border-b border-ink-faint/20 px-6 py-4">
          <h1 className="text-h2 font-display">Admin</h1>
          {actions}
        </header>
        <main className="p-6">{children}</main>
      </div>
    </div>
  );
}
