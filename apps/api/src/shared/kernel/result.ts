/**
 * Result — tipli hata taşıma (CLAUDE.md §4: boş catch yasak, hatalar tipli).
 * Use case'ler exception yerine Result döndürebilir; presentation katmanı
 * bunu HTTP'ye çevirir.
 */
export type Result<T, E = Error> =
  { readonly ok: true; readonly value: T } | { readonly ok: false; readonly error: E };

export const ok = <T>(value: T): Result<T, never> => ({ ok: true, value });
export const err = <E>(error: E): Result<never, E> => ({ ok: false, error });

export function isOk<T, E>(r: Result<T, E>): r is { ok: true; value: T } {
  return r.ok;
}
