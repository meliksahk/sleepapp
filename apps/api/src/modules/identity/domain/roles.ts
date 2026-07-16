/**
 * Admin panel rolleri (CLAUDE.md §3.3). Rol adları burada TEK kaynakta yaşar —
 * başka modül string literal yazmaz, bu tipi kullanır.
 *
 * - owner   : her şey (davet, rol atama, silme)
 * - editor  : içerik (soundscape/preset/haftalık yayın)
 * - analyst : salt okunur (metrikler)
 * - support : kullanıcı destek işlemleri
 */
export const ADMIN_ROLES = ['owner', 'editor', 'analyst', 'support'] as const;

export type AdminRole = (typeof ADMIN_ROLES)[number];

export function isAdminRole(value: string): value is AdminRole {
  return (ADMIN_ROLES as readonly string[]).includes(value);
}
