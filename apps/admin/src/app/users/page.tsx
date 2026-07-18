import { AppShell } from '@/shared/ui/AppShell';
import { apiGet } from '@/shared/api/server-client';
import { LogoutButton } from '@/features/auth/LogoutButton';
import { canViewUsers } from '@/features/users/can-view-users';
import { UserTable } from '@/features/users/UserTable';
import { translator } from '@/shared/i18n/dictionaries';
import { getLocale } from '@/shared/i18n/locale';
import type { AdminUser } from '@/features/users/types';

/**
 * Kullanıcı arama (docs/03 A2 destek senaryosu). Sunucu bileşeni: `?q=` okunur,
 * arama SSR yapılır (client JS yok — form GET ile `?q=`e gider).
 *
 * Çeviri `translate()` ile, `useT()` ile DEĞİL: hook kullanmak bileşeni istemciye
 * taşırdı ve "client JS yok" kararını bozardı.
 *
 * **Rol görünürlüğü:** yalnızca owner/support. Analyst/editor için bölüm gizli +
 * uyarı; gerçek kapı zaten sunucuda (API 403). "UI gizleme yeterli değil" (§3.3).
 */
export default async function UsersPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string }>;
}) {
  const locale = await getLocale();
  const t = translator(locale);
  const { q } = await searchParams;
  const query = (q ?? '').trim();
  const me = await apiGet<{ userId: string; roles: string[] }>('/v1/admin/me');

  if (!canViewUsers(me.roles)) {
    return (
      <AppShell actions={<LogoutButton />}>
        <h2 className="text-h2 font-display">{t('users.title')}</h2>
        <p className="mt-2 text-body text-ink-secondary">{t('users.noPermission')}</p>
      </AppShell>
    );
  }

  // ≥2 karakter: API kapısıyla aynı; boş/tek harf sorgu tüm tabanı çekmez.
  const users =
    query.length >= 2
      ? await apiGet<AdminUser[]>(`/v1/admin/users?q=${encodeURIComponent(query)}`)
      : [];

  return (
    <AppShell actions={<LogoutButton />}>
      <h2 className="text-h2 font-display">{t('users.title')}</h2>
      <p className="mt-1 mb-4 text-body text-ink-secondary">{t('users.subtitle')}</p>

      <form method="get" action="/users" className="mb-6 flex gap-2">
        <input
          type="search"
          name="q"
          defaultValue={query}
          placeholder={t('users.searchPlaceholder')}
          aria-label={t('users.searchLabel')}
          className="flex-1 rounded-chip border border-ink-faint/30 bg-transparent px-3 py-2 text-body"
        />
        <button
          type="submit"
          className="rounded-chip bg-accent-aurora px-4 py-2 text-body text-bg-base"
        >
          {t('users.searchSubmit')}
        </button>
      </form>

      {query.length >= 2 ? (
        <UserTable users={users} locale={locale} />
      ) : (
        <p className="text-body text-ink-secondary">{t('users.minChars')}</p>
      )}
    </AppShell>
  );
}
