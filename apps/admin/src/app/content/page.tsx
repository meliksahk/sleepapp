import { AppShell } from '@/shared/ui/AppShell';
import { apiGet } from '@/shared/api/server-client';
import { LogoutButton } from '@/features/auth/LogoutButton';
import { SoundscapeTable } from '@/features/content/SoundscapeTable';
import type { AdminSoundscape } from '@/features/content/types';

/** İçerik listesi (docs/03 A1). Taslak dahil TÜM soundscape'ler. */
export default async function ContentPage() {
  const rows = await apiGet<AdminSoundscape[]>('/v1/admin/soundscapes');

  return (
    <AppShell actions={<LogoutButton />}>
      <h2 className="text-h2 font-display">Soundscapes</h2>
      <p className="mt-1 mb-5 text-body text-ink-secondary">
        Taslak ve planlı kayıtlar dahil. Düzenleme A1&apos;in devamında gelecek.
      </p>
      <SoundscapeTable rows={rows} />
    </AppShell>
  );
}
