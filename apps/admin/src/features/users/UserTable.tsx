import { translate, type Locale } from '@/shared/i18n/dictionaries';
import { formatDate } from '@/shared/i18n/format';
import type { AdminUser } from './types';

/**
 * Kullanıcı arama sonuç tablosu (docs/03 A2 destek). Salt okuma — mutasyon yok.
 *
 * Sunucu bileşeni: dil PROP olarak gelir (`useT()` bir hook, burada çağrılamaz) —
 * sayfa bilinçli olarak sıfır client JS ile çalışıyor, o kararı bozmuyoruz.
 */
export function UserTable({ users, locale }: { users: AdminUser[]; locale: Locale }) {
  if (users.length === 0) {
    return <p className="text-body text-ink-secondary">{translate(locale, 'users.empty')}</p>;
  }
  return (
    <table className="w-full text-body">
      <thead>
        <tr className="border-b border-ink-faint/20 text-left text-ink-secondary">
          <th className="py-2 pr-4 font-normal">{translate(locale, 'users.colEmail')}</th>
          <th className="py-2 pr-4 font-normal">{translate(locale, 'users.colKind')}</th>
          <th className="py-2 pr-4 font-normal">{translate(locale, 'users.colCreated')}</th>
          <th className="py-2 font-normal">{translate(locale, 'users.colId')}</th>
        </tr>
      </thead>
      <tbody>
        {users.map((u) => (
          <tr key={u.id} className="border-b border-ink-faint/10">
            <td className="py-2 pr-4">{u.email ?? '—'}</td>
            <td className="py-2 pr-4">{u.kind}</td>
            {/* Ham ISO (YYYY-MM-DD) yerine dile duyarlı tarih: panel TR'ken de
                EN biçim basmak, tabloyu okuyan destek görevlisini yavaşlatıyordu. */}
            <td className="py-2 pr-4">{formatDate(locale, u.createdAt)}</td>
            <td className="py-2 font-mono text-caption text-ink-secondary">{u.id}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
