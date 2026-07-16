/**
 * Slug kuralı — URL'de ve derin linkte yaşar (`/a/{slug}`, `/library/{slug}`),
 * dolayısıyla kaçış gerektirmeyen küçük harf-kebab dışına çıkamaz.
 * 2–64: tek harflik slug anlamsız, 64 üstü URL'i şişirir.
 */
const SLUG_RE = /^[a-z0-9]+(-[a-z0-9]+)*$/;

export function isValidSlug(value: string): boolean {
  return value.length >= 2 && value.length <= 64 && SLUG_RE.test(value);
}
