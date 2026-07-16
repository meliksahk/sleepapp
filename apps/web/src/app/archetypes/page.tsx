import type { Metadata } from 'next';
import Link from 'next/link';
import { ARCHETYPES } from '@/content/archetypes';
import { buildArchetypeListJsonLd, buildBreadcrumbTrail } from '@/lib/schema';

export const metadata: Metadata = {
  title: 'Sleep Identities — All Archetypes | NOCTA',
  description:
    'Explore every NOCTA sleep identity. Find the one that fits your nights and the sounds that suit it.',
  openGraph: {
    title: 'Sleep Identities — All Archetypes',
    description: 'Explore every NOCTA sleep identity and the sounds that suit it.',
  },
};

export default function ArchetypesIndexPage() {
  const jsonLd = [
    buildArchetypeListJsonLd(ARCHETYPES),
    buildBreadcrumbTrail([
      { name: 'Home', path: '' },
      { name: 'Sleep identities', path: '/archetypes' },
    ]),
  ];
  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />
      <main className="mx-auto max-w-2xl p-5">
        <p className="text-caption uppercase tracking-widest text-ink-secondary">
          Sleep Identities
        </p>
        <h1 className="mt-1 text-display font-display">Which one are you?</h1>
        <p className="mt-2 text-body text-ink-secondary">
          Every sleeper has a rhythm. Explore the identities, then take the test to find yours.
        </p>

        <ul className="mt-8 flex flex-col gap-4">
          {ARCHETYPES.map((a) => (
            <li key={a.slug}>
              <Link
                href={`/a/${a.slug}`}
                className="block rounded-card border border-ink-faint/20 p-4 hover:border-ink-faint/40"
              >
                <h2 className="text-h2 font-display">{a.name}</h2>
                <p className="mt-1 text-body text-ink-secondary">{a.tagline}</p>
              </Link>
            </li>
          ))}
        </ul>

        <Link
          href="/test"
          className="mt-8 inline-block rounded-button bg-accent-aurora px-5 py-3 text-bg-base"
        >
          Take the sleep identity test
        </Link>
      </main>
    </>
  );
}
