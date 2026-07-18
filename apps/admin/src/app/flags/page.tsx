import { AppShell } from '@/shared/ui/AppShell';
import { apiGet } from '@/shared/api/server-client';
import { LogoutButton } from '@/features/auth/LogoutButton';
import { FlagTable } from '@/features/flags/FlagTable';
import { FlagForm } from '@/features/flags/FlagForm';
import { canEditFlags } from '@/features/flags/can-edit-flags';
import type { AdminFlag } from '@/features/flags/types';

/**
 * Feature flag rollout görünürlüğü + düzenleme (docs/03 A4). Sunucu bileşeni: ham flag
 * tanımları SSR çekilir. OKUMA her panel rolüne açık (flag tanımı PII değil); DÜZENLEME
 * yalnızca owner'a — form owner'a gösterilir, gerçek kapı sunucuda (#167 → 403).
 */
export default async function FlagsPage() {
  const [flags, me] = await Promise.all([
    apiGet<AdminFlag[]>('/v1/admin/flags'),
    apiGet<{ userId: string; roles: string[] }>('/v1/admin/me'),
  ]);
  const editable = canEditFlags(me.roles);

  return (
    <AppShell actions={<LogoutButton />}>
      <h2 className="text-h2 font-display">Feature Flags</h2>
      <p className="mt-1 mb-6 text-body text-ink-secondary">
        Rollout görünürlüğü — hangi özellik kime açık.
        {editable ? ' Owner olarak düzenleyebilirsiniz.' : ' Düzenleme yalnızca owner.'}
      </p>

      <FlagTable flags={flags} />

      {editable && (
        <section className="mt-8 border-t border-ink-faint/20 pt-6">
          <h3 className="text-body font-display">Flag oluştur / değiştir</h3>
          <FlagForm />
        </section>
      )}
    </AppShell>
  );
}
