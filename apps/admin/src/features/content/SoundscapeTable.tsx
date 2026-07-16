import { DataTable, type Column } from '@nocta/ui';
import type { AdminSoundscape } from './types';
import { statusLabel } from './status-label';

const columns: Column<AdminSoundscape>[] = [
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

export function SoundscapeTable({ rows }: { rows: AdminSoundscape[] }) {
  return <DataTable columns={columns} rows={rows} emptyTitle="Henüz soundscape yok" />;
}
