import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { BLOG_SLUGS, getBlogPost } from '@/content/blog';
import { BlogPostView } from '@/components/BlogPostView';
import { buildBlogBreadcrumbJsonLd, buildBlogPostJsonLd } from '@/lib/schema';

interface PageProps {
  params: Promise<{ slug: string }>;
}

export function generateStaticParams(): Array<{ slug: string }> {
  return BLOG_SLUGS.map((slug) => ({ slug }));
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { slug } = await params;
  const post = getBlogPost(slug);
  if (!post) return {};
  return {
    title: `${post.title} | NOCTA`,
    description: post.description,
    openGraph: { title: post.title, description: post.description, type: 'article' },
  };
}

export default async function BlogPostPage({ params }: PageProps) {
  const { slug } = await params;
  const post = getBlogPost(slug);
  if (!post) notFound();

  const jsonLd = [buildBlogPostJsonLd(post), buildBlogBreadcrumbJsonLd(post)];
  return (
    <>
      <script
        type="application/ld+json"
        // JSON-LD tek util'den üretilir; içerik güvenilir (kullanıcı girdisi değil).
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />
      <BlogPostView post={post} />
    </>
  );
}
