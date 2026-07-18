import { AppShell } from '@/shared/ui/AppShell';
import { apiGet } from '@/shared/api/server-client';
import { LogoutButton } from '@/features/auth/LogoutButton';
import { SoundscapeTable } from '@/features/content/SoundscapeTable';
import { NewSoundscapeForm } from '@/features/content/NewSoundscapeForm';
import { canWriteContent } from '@/features/content/can-write';
import { translator } from '@/shared/i18n/dictionaries';
import { getLocale } from '@/shared/i18n/locale';
import type { AdminSoundscape } from '@/features/content/types';

/** İçerik listesi + yeni taslak (docs/03 A1). Taslak dahil TÜM soundscape'ler. */
export default async function ContentPage() {
  const locale = await getLocale();
  const t = translator(locale);

  // Paralel: biri diğerini beklemesin (ikisi de bağımsız okuma).
  const [rows, me] = await Promise.all([
    apiGet<AdminSoundscape[]>('/v1/admin/soundscapes'),
    apiGet<{ userId: string; roles: string[] }>('/v1/admin/me'),
  ]);
  const canWrite = canWriteContent(me.roles);

  return (
    <AppShell actions={<LogoutButton />}>
      <h2 className="text-h2 font-display">{t('content.title')}</h2>
      <p className="mt-1 mb-5 text-body text-ink-secondary">{t('content.subtitle')}</p>

      {canWrite && (
        <section className="mb-8">
          <h3 className="mb-3 text-body font-display">{t('content.newDraft')}</h3>
          <NewSoundscapeForm />
        </section>
      )}

      <SoundscapeTable rows={rows} canWrite={canWrite} locale={locale} />
    </AppShell>
  );
}
