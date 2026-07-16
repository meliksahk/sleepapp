/**
 * Paylaşım oranını panelde gösterilecek metne çevirir.
 *
 * **null → "—", "%0" DEĞİL:** kimse testi tamamlamadıysa oran TANIMSIZDIR. "%0"
 * göstermek "kimse paylaşmıyor" demektir ve bu YANLIŞ bir ifadedir — insan ona
 * bakıp "viral kanca çalışmıyor" diye karar verir, oysa henüz kimse test bile
 * yapmamıştır. Yanlış metrik, olmayan metrikten kötüdür (#126'nın aynı ilkesi).
 */
export function shareRateLabel(rate: number | null): string {
  if (rate === null) return '—';
  return `%${Math.round(rate * 100)}`;
}

/** Ham sayılar: oran tek başına yanıltıcıdır — 1/1 de "%100" görünür. */
export function shareRateHint(completed: number, shared: number): string {
  if (completed === 0) return 'henüz test tamamlanmadı';
  return `${shared}/${completed} kişi`;
}
