import { describe, it, expect } from 'vitest';
import {
  BLOG_POSTS_ALL as BLOG_POSTS,
  BLOG_SLUGS,
  getBlogPost,
  blogPostsNewestFirst,
} from './blog';

/** Blog içeriği long-tail SEO'nun gövdesi; yapı + sağlık-iddiası kapısı burada kilitli. */
describe('blog content', () => {
  it('benzersiz slug', () => {
    expect(new Set(BLOG_SLUGS).size).toBe(BLOG_POSTS.length);
  });

  it('getBlogPost bilinen/bilinmeyen slug', () => {
    expect(getBlogPost('wind-down-ritual')?.title).toBeTruthy();
    expect(getBlogPost('nope')).toBeUndefined();
  });

  it('her yazı zorunlu alanlara + gerçek içeriğe sahip', () => {
    for (const p of BLOG_POSTS) {
      expect(p.title).toBeTruthy();
      expect(p.description.length).toBeGreaterThan(30);
      expect(p.intro.length).toBeGreaterThan(60);
      expect(p.sections.length).toBeGreaterThanOrEqual(2);
      expect(p.readingMinutes).toBeGreaterThan(0);
      // ISO tarih parse edilebilir (Article datePublished geçerli olmalı).
      expect(Number.isNaN(Date.parse(p.publishedAt))).toBe(false);
      for (const s of p.sections) {
        expect(s.heading).toBeTruthy();
        expect(s.paragraphs.length).toBeGreaterThanOrEqual(1);
      }
    }
  });

  it('ÇEKİRDEK: sağlık iddiası taraması — yasak kelime yok (CLAUDE.md §1.1)', () => {
    // tooling/check-health-claims.mjs ile aynı küme (site metni FTC/App Store kapısı).
    const forbidden =
      /\b(cures?|cured|treats?|treatments?|therapy|therapeutic|clinical(ly)?|medical(ly)?|diseases?|tedavi)\b|science[- ]backed|doctor[- ]approved/i;
    for (const p of BLOG_POSTS) {
      const text = [
        p.title,
        p.description,
        p.intro,
        ...p.sections.flatMap((s) => [s.heading, ...s.paragraphs]),
      ].join(' ');
      expect(text).not.toMatch(forbidden);
    }
  });

  it('blogPostsNewestFirst tarihe göre azalan sıralar', () => {
    const dates = blogPostsNewestFirst().map((p) => p.publishedAt);
    const descending = [...dates].sort((a, b) => b.localeCompare(a));
    expect(dates).toEqual(descending);
  });
});
