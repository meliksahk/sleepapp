import type { Metadata } from 'next';
import Link from 'next/link';
import { blogPostsNewestFirst } from '@/content/blog';

export const metadata: Metadata = {
  title: 'Blog — Sleep Rituals & Soundscapes | NOCTA',
  description:
    'Plain-language guides to wind-down rituals, soundscapes, and building an evening routine around your sleep identity.',
  openGraph: {
    title: 'NOCTA Blog — Sleep Rituals & Soundscapes',
    description: 'Guides to wind-down rituals and soundscapes for a calmer bedtime.',
  },
};

export default function BlogIndexPage() {
  const posts = blogPostsNewestFirst();
  return (
    <main className="mx-auto max-w-2xl p-5">
      <p className="text-caption uppercase tracking-widest text-ink-secondary">NOCTA</p>
      <h1 className="mt-1 text-display font-display">Blog</h1>
      <p className="mt-2 text-body text-ink-secondary">
        Simple guides to sleep rituals, soundscapes, and the rhythm of your nights.
      </p>

      <ul className="mt-8 flex flex-col gap-6">
        {posts.map((post) => (
          <li key={post.slug} className="border-t border-ink-faint/20 pt-6">
            <Link href={`/blog/${post.slug}`} className="group">
              <h2 className="text-h2 font-display group-hover:underline">{post.title}</h2>
              <p className="mt-1 text-caption text-ink-secondary">
                <time dateTime={post.publishedAt}>
                  {new Date(post.publishedAt).toISOString().slice(0, 10)}
                </time>{' '}
                · {post.readingMinutes} min read
              </p>
              <p className="mt-2 text-body text-ink-secondary">{post.description}</p>
            </Link>
          </li>
        ))}
      </ul>
    </main>
  );
}
