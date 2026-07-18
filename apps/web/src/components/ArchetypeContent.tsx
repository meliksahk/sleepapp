import Link from 'next/link';
import { ARCHETYPES, type ArchetypeContent as Archetype } from '@/content/archetypes';
import { ShareButton } from '@/components/ShareButton';
import { ShareCard } from '@/components/ShareCard';

const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://nocta.app';

export function ArchetypeContent({ archetype }: { archetype: Archetype }) {
  const shareUrl = `${SITE_URL}/a/${archetype.slug}`;
  const others = ARCHETYPES.filter((a) => a.slug !== archetype.slug);
  return (
    <article className="mx-auto max-w-2xl p-5">
      <p className="text-caption uppercase tracking-widest text-ink-secondary">Sleep Identity</p>
      <h1 className="mt-1 text-display font-display">{archetype.name}</h1>
      <p className="mt-2 text-body text-ink-secondary">{archetype.tagline}</p>

      {/* GEO: kısa, alıntılanabilir cevap bloğu */}
      <p className="mt-6 text-body">{archetype.summary}</p>

      {archetype.paragraphs.map((p, i) => (
        <p key={i} className="mt-4 text-body text-ink-secondary">
          {p}
        </p>
      ))}

      <h2 className="mt-8 text-h2 font-display">Sounds that suit you</h2>
      <ul className="mt-2 list-disc pl-5 text-ink-secondary">
        {archetype.soundsThatHelp.map((s) => (
          <li key={s}>{s}</li>
        ))}
      </ul>

      <div className="mt-8 flex flex-wrap items-center gap-3">
        <a
          href="/test"
          className="inline-block rounded-button bg-accent-aurora px-5 py-3 text-bg-base"
        >
          Take the sleep identity test
        </a>
        <ShareButton title={`My sleep identity is ${archetype.name}`} url={shareUrl} />
      </div>

      {/* Viral kanca (docs/05): indirilebilir paylaşım kartı */}
      <section className="mt-8" aria-label="Shareable card">
        <h2 className="text-h2 font-display">Share your identity</h2>
        <p className="mt-1 mb-4 text-body text-ink-secondary">Save a 9:16 card for stories.</p>
        <ShareCard
          slug={archetype.slug}
          name={archetype.name}
          tagline={archetype.tagline}
          sounds={archetype.soundsThatHelp}
        />
      </section>

      {/* İç bağlantı (SEO): diğer sleep identity'leri */}
      <nav aria-label="Other sleep identities" className="mt-10 border-t border-ink-faint/20 pt-6">
        <h2 className="text-h2 font-display">Other sleep identities</h2>
        <ul className="mt-3 flex flex-col gap-2">
          {others.map((a) => (
            <li key={a.slug}>
              <Link href={`/a/${a.slug}`} className="text-body text-accent-aurora hover:underline">
                {a.name} — {a.tagline}
              </Link>
            </li>
          ))}
        </ul>
      </nav>
    </article>
  );
}
