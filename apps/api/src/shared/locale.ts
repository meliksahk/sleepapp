/**
 * API'nin dil çözümü — tek kaynak (CLAUDE.md §4: i18n baştan itibaren).
 *
 * **Neden header, neden query parametresi değil:** dil bir SUNUM tercihidir, kaynak
 * kimliğinin parçası değil. `/v1/archetype/questions` her dilde AYNI kaynağı döner;
 * yalnızca gösterimi değişir. Query parametresi olsaydı aynı içeriğin iki ayrı URL'i
 * olur, cache ve paylaşım linkleri bölünürdü.
 *
 * **Varsayılan EN:** birincil dil EN (CLAUDE.md §4). Tanımadığımız bir dil gelirse
 * sessizce EN'e düşeriz — istemciye hata dönmek, sırf dili desteklemiyoruz diye
 * çalışan bir isteği kırardı.
 */
export const SUPPORTED_LOCALES = ['en', 'tr'] as const;
export type Locale = (typeof SUPPORTED_LOCALES)[number];
export const DEFAULT_LOCALE: Locale = 'en';

function isSupported(tag: string): tag is Locale {
  return (SUPPORTED_LOCALES as readonly string[]).includes(tag);
}

/**
 * RFC 9110 `Accept-Language` başlığını çözer: `tr-TR,tr;q=0.9,en;q=0.8` → `tr`.
 *
 * Kalite (`q`) değerlerine SAYGI GÖSTERİR — `en;q=0.9,tr;q=0.3` için `en` döner.
 * Alt etiketler soyulur (`tr-TR` → `tr`) çünkü bölgesel varyantımız yok.
 * Başlık yoksa/bozuksa/desteklenmiyorsa [DEFAULT_LOCALE].
 */
export function resolveLocale(acceptLanguage?: string | null): Locale {
  if (!acceptLanguage) return DEFAULT_LOCALE;

  const candidates = acceptLanguage
    .split(',')
    .map((part) => {
      const [tag, ...params] = part.trim().split(';');
      const qParam = params.find((p) => p.trim().startsWith('q='));
      // Bozuk q ("q=abc") 0 DEĞİL 1 sayılır: RFC'ye göre q yoksa varsayılan 1'dir ve
      // bozuk bir parametre yüzünden dili tümden elemek istemiyoruz.
      const parsed = qParam ? Number.parseFloat(qParam.trim().slice(2)) : 1;
      const q = Number.isFinite(parsed) ? parsed : 1;
      // `split` her zaman en az bir eleman döner; `?? ''` yalnızca tip daraltması
      // için (noUncheckedIndexedAccess) — boş etiket zaten desteklenmeyen sayılır.
      const base = (tag ?? '').trim().toLowerCase().split('-')[0] ?? '';
      return { tag: base, q };
    })
    // q=0 "bu dili İSTEMİYORUM" demektir (RFC) — elenir.
    .filter((c) => c.q > 0)
    .sort((a, b) => b.q - a.q);

  // `find` eleman tipini daraltmaz (tip koruyucu iç alandaysa) — bu yüzden önce
  // etiketleri çıkarıp doğrudan daraltılabilir bir dizi üzerinde arıyoruz.
  return candidates.map((c) => c.tag).find(isSupported) ?? DEFAULT_LOCALE;
}
