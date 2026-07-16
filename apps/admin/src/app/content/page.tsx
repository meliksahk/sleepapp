import { AppShell } from '@/shared/ui/AppShell';
import { apiGet } from '@/shared/api/server-client';
import { LogoutButton } from '@/features/auth/LogoutButton';
import { SoundscapeTable } from '@/features/content/SoundscapeTable';
import { NewSoundscapeForm } from '@/features/content/NewSoundscapeForm';
import { canWriteContent } from '@/features/content/can-write';
import type { AdminSoundscape } from '@/features/content/types';

/** İçerik listesi + yeni taslak (docs/03 A1). Taslak dahil TÜM soundscape'ler. */
export default async function ContentPage() {
  // Paralel: biri diğerini beklemesin (ikisi de bağımsız okuma).
  const [rows, me] = await Promise.all([
    apiGet<AdminSoundscape[]>('/v1/admin/soundscapes'),
    apiGet<{ userId: string; roles: string[] }>('/v1/admin/me'),
  ]);
  const canWrite = canWriteContent(me.roles);

  return (
    <AppShell actions={<LogoutButton />}>
      <h2 className="text-h2 font-display">Soundscapes</h2>
      <p className="mt-1 mb-5 text-body text-ink-secondary">
        Taslak ve planlı kayıtlar dahil. Yayınlama ve düzenleme A1&apos;in devamında.
      </p>

      {canWrite && (
        <section className="mb-8">
          <h3 className="mb-3 text-body font-display">Yeni taslak</h3>
          <NewSoundscapeForm />
        </section>
      )}

      <SoundscapeTable rows={rows} />
    </AppShell>
  );
}
