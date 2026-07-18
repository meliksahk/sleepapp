/**
 * Paylaşım kartı (docs/05 viral kanca) — saf yardımcılar. Canvas ÇİZİMİ tarayıcıda
 * (`ShareCard.tsx`) yapılır; buradaki mantık (metin sarma, dosya adı) cihazsız test'li.
 */

/** 9:16 IG-story formatı (CLAUDE.md §1.1 viral format). */
export const CARD_WIDTH = 1080;
export const CARD_HEIGHT = 1920;

/** İndirilecek dosya adı — slug'dan türetilir (marka öneki). */
export function cardFileName(slug: string): string {
  const safe = slug.replace(/[^a-z0-9-]/gi, '').toLowerCase() || 'card';
  return `nocta-${safe}.png`;
}

/**
 * Metni [maxWidth] piksele sığacak satırlara böler. Canvas otomatik sarmaz; her
 * kelimeyi ekleyip genişliği ölçerek elle sararız. [measure] enjekte edilir (gerçekte
 * `ctx.measureText(s).width`) → jsdom'da canvas olmadan sahte ölçüyle test edilebilir.
 *
 * Tek kelime maxWidth'i aşarsa kırpmadan kendi satırında bırakılır (kart bozulmaz;
 * archetype adları kısadır — "3AM Overthinker" en uzunu).
 */
export function wrapText(text: string, maxWidth: number, measure: (s: string) => number): string[] {
  const words = text.split(/\s+/).filter((w) => w.length > 0);
  const lines: string[] = [];
  // Boş dize sentinel: filtrelenmiş kelimeler asla boş değil, güvenli (index erişimsiz).
  let current = '';
  for (const word of words) {
    if (current === '') {
      current = word;
      continue;
    }
    const candidate = `${current} ${word}`;
    if (measure(candidate) <= maxWidth) {
      current = candidate;
    } else {
      lines.push(current);
      current = word;
    }
  }
  if (current !== '') lines.push(current);
  return lines;
}
