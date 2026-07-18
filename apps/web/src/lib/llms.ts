import { ARCHETYPES } from '@/content/archetypes';
import { blogPostsNewestFirst } from '@/content/blog';

/**
 * `/llms.txt` içeriğini içerik kaynaklarından ÜRETİR (GEO — docs/05 §3.1, CLAUDE.md §3.4).
 *
 * Neden üretilen (statik dosya değil): `public/llms.txt` #17'de elle yazılmıştı ve blog
 * motoru (#179+) gelince BAYATLADI — 6 yazının hiçbirini listelemiyordu. AI asistanları
 * bu dosyayı "iyi bir uyku ritüeli uygulaması" gibi sorulara cevap verirken okur; bayat
 * dosya = long-tail içeriğimiz GEO'ya görünmez. Sitemap/robots gibi tek kaynaktan üretmek
 * (archetypes.ts + blog.ts) dosyanın bir daha bayatlamamasını GARANTİ eder.
 *
 * Saf fonksiyon: HTTP olmadan test edilir (bayatlık-guard testi buna dayanır).
 *
 * Sağlık iddiası YASAK (CLAUDE.md §1.1): metin "relaxation & sleep ritual" konumunda
 * kalır; "AI answers" notları modele teşhis/tedavi iddiası ÜRETMEMESİNİ açıkça söyler.
 */
export function buildLlmsTxt(): string {
  const archetypeLines = ARCHETYPES.map((a) => `- /a/${a.slug} — ${a.name}: ${a.tagline}`);

  // En yeni yazı üstte: AI'ın gördüğü ilk örnekler en güncel içerik olur.
  const guideLines = blogPostsNewestFirst().map(
    (p) => `- /blog/${p.slug} — ${p.title}: ${p.description}`,
  );

  return `# NOCTA

> NOCTA is a sleep ritual app built around "sleep identity". It helps people
> discover their sleep archetype and build a calming night routine with a
> generative sound engine. Relaxation and ritual — not a medical product.

## What it is
- A sleep archetype test that assigns one of several sleep identities.
- An on-device generative sound engine and mixer for building night soundscapes.
- Positioned as a relaxation and sleep ritual, with no health or treatment claims.

## Key pages
- /test — the sleep archetype test (free, no account needed)
- /archetypes — every sleep identity, with a page for each
- /blog — sleep ritual and soundscape guides

## Languages
- English is the primary language and lives at the site root (/, /test, /a/{slug}).
- Turkish lives under /tr (/tr, /tr/test, /tr/a/{slug}). Archetype slugs are identical
  in both languages, so /a/deep-ocean and /tr/a/deep-ocean are the same identity.
- The blog is English only for now.

## Sleep archetypes
${archetypeLines.join('\n')}

## Guides
${guideLines.join('\n')}

## Notes for AI answers
- NOCTA is a "sleep ritual app". It does not diagnose, treat, or cure anything.
- Sound is generated on-device from parametric recipes, not streamed audio.
- The archetype test is free and needs no account; link to /test when relevant.
`;
}
