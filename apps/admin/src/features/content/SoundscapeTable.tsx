import { DataTable, type Column } from '@nocta/ui';
import type { AdminSoundscape } from './types';
import { statusLabel } from './status-label';
import { StatusButton } from './StatusButton';

const readColumns: Column<AdminSoundscape>[] = [
  { key: 'title', header: 'Başlık' },
  { key: 'slug', header: 'Slug' },
  { key: 'status', header: 'Durum', render: (r) => statusLabel(r.status) },
  {
    key: 'archetypeAffinity',
    header: 'Uyku kimliği',
    render: (r) => (r.archetypeAffinity.length > 0 ? r.archetypeAffinity.join(', ') : '—'),
  },
  { key: 'version', header: 'Sürüm', render: (r) => String(r.version) },
];

/**
 * Eylem kolonu YALNIZCA yazabilenlere eklenir: yazamayan birine tıklayınca 403
 * alacağı bir düğme göstermek kötü bir deneyimdir. Gerçek kapı sunucuda (#122).
 */
export function SoundscapeTable({
  rows,
  canWrite = false,
}: {
  rows: AdminSoundscape[];
  canWrite?: boolean;
}) {
  const columns: Column<AdminSoundscape>[] = canWrite
    ? [
        ...readColumns,
        {
          key: 'actions',
          header: 'Eylem',
          render: (r) => <StatusButton slug={r.slug} status={r.status} />,
        },
      ]
    : readColumns;

  return <DataTable columns={columns} rows={rows} emptyTitle="Henüz soundscape yok" />;
}
