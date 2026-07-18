import { describe, it, expect } from 'vitest';
import { buildLlmsTxt } from './llms';
import { ARCHETYPES } from '@/content/archetypes';
import { BLOG_POSTS_ALL } from '@/content/blog';

/**
 * llms.txt BAYATLIK GUARD'ı.
 *
 * Bu dosyanın var olma sebebi: eski statik public/llms.txt, blog motoru gelince sessizce
 * bayatladı (6 yazının hiçbirini listelemiyordu). Üretilen sürüm tek kaynaktan gelir; bu
 * testler her arketip VE her blog yazısının çıktıda göründüğünü kilitleyerek aynı
 * bayatlamanın tekrarını imkânsız kılar — yeni içerik eklenince otomatik dahil olur.
 */
describe('buildLlmsTxt (GEO — bayatlık guard)', () => {
  const txt = buildLlmsTxt();

  it('HER arketibi slug + ad ile listeler (biri eksikse bu test kırılır)', () => {
    for (const a of ARCHETYPES) {
      expect(txt).toContain(`/a/${a.slug}`);
      expect(txt).toContain(a.name);
    }
  });

  it('HER blog yazısını slug + başlık ile listeler (long-tail GEO görünürlüğü)', () => {
    // ÇEKİRDEK: eski dosyanın kaçırdığı tam buydu — yazılar yoktu.
    for (const p of BLOG_POSTS_ALL) {
      expect(txt).toContain(`/blog/${p.slug}`);
      expect(txt).toContain(p.title);
    }
  });

  it('"sleep ritual" konumunu + tedavi-etmez feragatnamesini taşır (CLAUDE.md §1.1)', () => {
    // Not: sağlık-iddiası TARAMASI ayrı bir CI kapısıdır (check:health-claims); burada
    // yalnızca konumlandırma cümlelerinin KAYBOLMADIĞINI kilitliyoruz. Feragatnamedeki
    // "treat/cure" iddia değildir, o yüzden naif kelime-blocklist'i kullanmıyoruz.
    expect(txt).toContain('sleep ritual');
    expect(txt).toMatch(/does not diagnose, treat, or cure/i);
    expect(txt).toMatch(/no health or treatment claims/i);
  });

  it('/test ve /blog gibi giriş sayfalarına yönlendirir', () => {
    expect(txt).toContain('/test');
    expect(txt).toContain('/blog');
  });
});
