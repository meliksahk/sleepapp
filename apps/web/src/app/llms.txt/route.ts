import { buildLlmsTxt } from '@/lib/llms';

// GEO: /llms.txt üretilen rota (sitemap/robots gibi). İçerik statik olduğundan
// build'de bir kez üretilir (SSG). Eski public/llms.txt kaldırıldı — bkz. lib/llms.ts.
export const dynamic = 'force-static';

export function GET(): Response {
  return new Response(buildLlmsTxt(), {
    headers: { 'content-type': 'text/plain; charset=utf-8' },
  });
}
