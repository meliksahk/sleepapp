import { DataTable, type Column } from '@nocta/ui';
import { translate, type Locale } from '@/shared/i18n/dictionaries';
import { formatDateTime } from '@/shared/i18n/format';
import { auditActionLabel } from './audit-label';

export interface AuditEntry {
  id: string;
  actorEmail: string;
  action: string;
  target: string;
  createdAt: string;
}

/**
 * Kolonlar dile bağlı → modül seviyesinde sabit tutulamaz, render'da kurulur.
 *
 * Zaman: sunucu UTC gönderir (CLAUDE.md §4). Biçim artık PANEL DİLİNE göre
 * (`toLocaleString()` sunucunun varsayılan dilini kullanıyordu, panel diliyle
 * senkron değildi). Saat dilimi hâlâ sunucununki — bkz. shared/i18n/format.ts.
 */
function columns(locale: Locale): Column<AuditEntry>[] {
  return [
    { key: 'actorEmail', header: translate(locale, 'audit.colWho') },
    {
      key: 'action',
      header: translate(locale, 'audit.colWhat'),
      render: (r) => auditActionLabel(locale, r.action),
    },
    { key: 'target', header: translate(locale, 'audit.colTarget') },
    {
      key: 'createdAt',
      header: translate(locale, 'audit.colWhen'),
      render: (r) => formatDateTime(locale, r.createdAt),
    },
  ];
}

/** Son panel etkinlikleri. #126'da kaldırılan SAHTE tablo — artık gerçek veriyle. */
export function AuditFeed({ entries, locale }: { entries: AuditEntry[]; locale: Locale }) {
  // `emptyTitle` çevrilmiş geçilir: @nocta/ui paylaşılan paket, admin sözlüğünü bilemez.
  return (
    <DataTable
      columns={columns(locale)}
      rows={entries}
      emptyTitle={translate(locale, 'audit.empty')}
    />
  );
}
