import { AppShell } from '@/shared/ui/AppShell';
import { apiGet } from '@/shared/api/server-client';
import { LogoutButton } from '@/features/auth/LogoutButton';
import { FlagTable } from '@/features/flags/FlagTable';
import type { AdminFlag } from '@/features/flags/types';

/**
 * Feature flag rollout görünürlüğü (docs/03 A4). Sunucu bileşeni: ham flag tanımları
 * SSR çekilir. Salt okuma → her panel rolü görebilir (API `GET /v1/admin/flags` her
 * admin rolüne açık; flag tanımı PII değil — kullanıcı aramasının aksine). Gerçek kapı
 * sunucuda: admin olmayana zaten 403.
 *
 * Düzenleme (upsert) burada YOK — owner-kapılı ayrı iş olacak (audit-action ister).
 */
export default async function FlagsPage() {
  const flags = await apiGet<AdminFlag[]>('/v1/admin/flags');

  return (
    <AppShell actions={<LogoutButton />}>
      <h2 className="text-h2 font-display">Feature Flags</h2>
      <p className="mt-1 mb-6 text-body text-ink-secondary">
        Rollout görünürlüğü — hangi özellik kime açık. Düzenleme yakında.
      </p>
      <FlagTable flags={flags} />
    </AppShell>
  );
}
