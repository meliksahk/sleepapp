import Link from 'next/link';
import type { BlogPost } from '@/content/blog';

/** Tek blog yazısı görünümü — semantik HTML (SEO): article/h1/h2, GEO özet bloğu. */
export function BlogPostView({ post }: { post: BlogPost }) {
  return (
    <article className="mx-auto max-w-2xl p-5">
      <p className="text-caption uppercase tracking-widest text-ink-secondary">Sleep ritual</p>
      <h1 className="mt-1 text-display font-display">{post.title}</h1>
      <p className="mt-2 text-caption text-ink-secondary">
        <time dateTime={post.publishedAt}>
          {new Date(post.publishedAt).toISOString().slice(0, 10)}
        </time>{' '}
        · {post.readingMinutes} min read
      </p>

      {/* GEO: kısa, alıntılanabilir cevap bloğu */}
      <p className="mt-6 text-body">{post.intro}</p>

      {post.sections.map((section) => (
        <section key={section.heading} className="mt-8">
          <h2 className="text-h2 font-display">{section.heading}</h2>
          {section.paragraphs.map((p, i) => (
            <p key={i} className="mt-3 text-body text-ink-secondary">
              {p}
            </p>
          ))}
        </section>
      ))}

      <div className="mt-10 flex flex-wrap items-center gap-3">
        <a
          href="/test"
          className="inline-block rounded-button bg-accent-aurora px-5 py-3 text-bg-base"
        >
          Take the sleep identity test
        </a>
        <Link href="/blog" className="text-body text-accent-aurora hover:underline">
          More from the blog
        </Link>
      </div>
    </article>
  );
}
