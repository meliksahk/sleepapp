import { AppShell } from '@/shared/ui/AppShell';
import { apiGet } from '@/shared/api/server-client';
import { LogoutButton } from '@/features/auth/LogoutButton';
import { canViewUsers } from '@/features/users/can-view-users';
import { UserTable } from '@/features/users/UserTable';
import type { AdminUser } from '@/features/users/types';

/**
 * Kullanıcı arama (docs/03 A2 destek senaryosu). Sunucu bileşeni: `?q=` okunur,
 * arama SSR yapılır (client JS yok — form GET ile `?q=`e gider).
 *
 * **Rol görünürlüğü:** yalnızca owner/support. Analyst/editor için bölüm gizli +
 * uyarı; gerçek kapı zaten sunucuda (API 403). "UI gizleme yeterli değil" (§3.3).
 */
export default async function UsersPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string }>;
}) {
  const { q } = await searchParams;
  const query = (q ?? '').trim();
  const me = await apiGet<{ userId: string; roles: string[] }>('/v1/admin/me');

  if (!canViewUsers(me.roles)) {
    return (
      <AppShell actions={<LogoutButton />}>
        <h2 className="text-h2 font-display">Kullanıcılar</h2>
        <p className="mt-2 text-body text-ink-secondary">
          Bu bölüm için yetkiniz yok (owner veya support gerekir).
        </p>
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
      <h2 className="text-h2 font-display">Kullanıcılar</h2>
      <p className="mt-1 mb-4 text-body text-ink-secondary">
        E-posta veya kullanıcı kimliğiyle ara (destek senaryosu).
      </p>

      <form method="get" action="/users" className="mb-6 flex gap-2">
        <input
          type="search"
          name="q"
          defaultValue={query}
          placeholder="e-posta veya id…"
          aria-label="Kullanıcı ara"
          className="flex-1 rounded-chip border border-ink-faint/30 bg-transparent px-3 py-2 text-body"
        />
        <button
          type="submit"
          className="rounded-chip bg-accent-aurora px-4 py-2 text-body text-bg-base"
        >
          Ara
        </button>
      </form>

      {query.length >= 2 ? (
        <UserTable users={users} />
      ) : (
        <p className="text-body text-ink-secondary">Aramak için en az 2 karakter girin.</p>
      )}
    </AppShell>
  );
}
