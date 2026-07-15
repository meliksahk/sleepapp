import type { ArchetypeContent as Archetype } from '@/content/archetypes';

export function ArchetypeContent({ archetype }: { archetype: Archetype }) {
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

      <a
        href="/test"
        className="mt-8 inline-block rounded-button bg-accent-aurora px-5 py-3 text-bg-base"
      >
        Take the sleep identity test
      </a>
    </article>
  );
}
