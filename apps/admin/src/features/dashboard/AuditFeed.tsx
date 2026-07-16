import { DataTable, type Column } from '@nocta/ui';
import { auditActionLabel } from './audit-label';

export interface AuditEntry {
  id: string;
  actorEmail: string;
  action: string;
  target: string;
  createdAt: string;
}

const columns: Column<AuditEntry>[] = [
  { key: 'actorEmail', header: 'Kim' },
  { key: 'action', header: 'Ne yaptı', render: (r) => auditActionLabel(r.action) },
  { key: 'target', header: 'Neye' },
  {
    key: 'createdAt',
    header: 'Ne zaman',
    // Sunucu UTC gönderir (CLAUDE.md §4); gösterim KULLANICININ saatiyle olmalı —
    // "03:14'te yayınlanmış" derken editörün kendi saatini kastediyoruz.
    render: (r) => new Date(r.createdAt).toLocaleString(),
  },
];

/** Son panel etkinlikleri. #126'da kaldırılan SAHTE tablo — artık gerçek veriyle. */
export function AuditFeed({ entries }: { entries: AuditEntry[] }) {
  return <DataTable columns={columns} rows={entries} emptyTitle="Henüz etkinlik yok" />;
}
