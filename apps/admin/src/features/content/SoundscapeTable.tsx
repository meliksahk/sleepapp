import { DataTable, type Column } from '@nocta/ui';
import { translate, type Locale } from '@/shared/i18n/dictionaries';
import type { AdminSoundscape } from './types';
import { statusLabel } from './status-label';
import { StatusButton } from './StatusButton';

/**
 * Sunucu bileşeni: dil PROP olarak gelir (`useT()` bir hook, burada çağrılamaz).
 * Kolonlar dile bağlı olduğu için modül seviyesinde sabit tutulamaz, render'da kurulur.
 */
function readColumns(locale: Locale): Column<AdminSoundscape>[] {
  return [
    { key: 'title', header: translate(locale, 'content.colTitle') },
    { key: 'slug', header: translate(locale, 'content.colSlug') },
    {
      key: 'status',
      header: translate(locale, 'content.colStatus'),
      render: (r) => statusLabel(locale, r.status),
    },
    {
      key: 'archetypeAffinity',
      header: translate(locale, 'content.colAffinity'),
      render: (r) => (r.archetypeAffinity.length > 0 ? r.archetypeAffinity.join(', ') : '—'),
    },
    {
      key: 'version',
      header: translate(locale, 'content.colVersion'),
      render: (r) => String(r.version),
    },
  ];
}

/**
 * Eylem kolonu YALNIZCA yazabilenlere eklenir: yazamayan birine tıklayınca 403
 * alacağı bir düğme göstermek kötü bir deneyimdir. Gerçek kapı sunucuda (#122).
 */
export function SoundscapeTable({
  rows,
  locale,
  canWrite = false,
}: {
  rows: AdminSoundscape[];
  locale: Locale;
  canWrite?: boolean;
}) {
  const base = readColumns(locale);
  const columns: Column<AdminSoundscape>[] = canWrite
    ? [
        ...base,
        {
          key: 'actions',
          header: translate(locale, 'content.colAction'),
          render: (r) => <StatusButton slug={r.slug} status={r.status} />,
        },
      ]
    : base;

  // `emptyTitle` ÇEVRİLMİŞ geçiliyor: @nocta/ui paylaşılan bir paket (web de kullanıyor)
  // ve admin'in sözlüğünü bilemez — varsayılanı orada değiştirmek paketin API'sini bozardı.
  return (
    <DataTable columns={columns} rows={rows} emptyTitle={translate(locale, 'content.empty')} />
  );
}
