import type { Metadata } from 'next';
import Link from 'next/link';
import { FAQ_ITEMS } from '@/content/faq';
import { buildBreadcrumbTrail, buildFaqJsonLd } from '@/lib/schema';

export const metadata: Metadata = {
  title: 'FAQ — NOCTA Sleep Ritual',
  description:
    'Answers about NOCTA: what a sleep identity is, the free tier, offline sound engine, privacy, and shareable cards.',
  openGraph: {
    title: 'NOCTA FAQ',
    description:
      'What NOCTA is, how the sleep identity test works, pricing, offline use, and privacy.',
  },
};

export default function FaqPage() {
  const jsonLd = [
    buildFaqJsonLd(FAQ_ITEMS),
    buildBreadcrumbTrail([
      { name: 'Home', path: '' },
      { name: 'FAQ', path: '/faq' },
    ]),
  ];
  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />
      <main className="mx-auto max-w-2xl p-5">
        <p className="text-caption uppercase tracking-widest text-ink-secondary">Questions</p>
        <h1 className="mt-1 text-display font-display">Frequently asked</h1>

        <dl className="mt-8 flex flex-col gap-6">
          {FAQ_ITEMS.map((item) => (
            <div key={item.question}>
              <dt className="text-h2 font-display">{item.question}</dt>
              <dd className="mt-1 text-body text-ink-secondary">{item.answer}</dd>
            </div>
          ))}
        </dl>

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
