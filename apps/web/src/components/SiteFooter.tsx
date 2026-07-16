import Link from 'next/link';

/** Site geneli footer — iç bağlantı (SEO sinyali) + keşfedilebilirlik. Her sayfada
 * (root layout). Sağlık iddiası YOK: "relaxation & sleep ritual" konumlandırması. */
const LINKS: ReadonlyArray<{ href: string; label: string }> = [
  { href: '/archetypes', label: 'Sleep identities' },
  { href: '/test', label: 'Take the test' },
  { href: '/faq', label: 'FAQ' },
];

export function SiteFooter() {
  return (
    <footer className="mx-auto mt-16 max-w-2xl border-t border-ink-faint/20 p-5">
      <nav aria-label="Footer" className="flex flex-wrap gap-x-6 gap-y-2">
        {LINKS.map((l) => (
          <Link
            key={l.href}
            href={l.href}
            className="text-body text-ink-secondary hover:text-ink-primary"
          >
            {l.label}
          </Link>
        ))}
      </nav>
      <p className="mt-4 text-caption text-ink-faint">
        NOCTA — a relaxation and sleep ritual. © 2026
      </p>
    </footer>
  );
}
