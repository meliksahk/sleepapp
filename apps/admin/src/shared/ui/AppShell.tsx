import type { ReactNode } from 'react';

const NAV = ['Dashboard', 'Content', 'Users', 'Analytics', 'Flags', 'Campaigns'];

/** Panel iskeleti: sidebar + topbar + içerik (docs/03 A0). Rol-guard'lı navigasyon B3'te. */
export function AppShell({ children }: { children: ReactNode }) {
  return (
    <div className="flex min-h-screen bg-bg-base text-ink-primary">
      <aside className="w-56 shrink-0 border-r border-ink-faint/20 p-4">
        <p className="text-h2 font-display">NOCTA</p>
        <nav className="mt-6 flex flex-col gap-1">
          {NAV.map((item) => (
            <span key={item} className="rounded-chip px-3 py-2 text-body text-ink-secondary">
              {item}
            </span>
          ))}
        </nav>
      </aside>
      <div className="flex-1">
        <header className="border-b border-ink-faint/20 px-6 py-4">
          <h1 className="text-h2 font-display">Admin</h1>
        </header>
        <main className="p-6">{children}</main>
      </div>
    </div>
  );
}
