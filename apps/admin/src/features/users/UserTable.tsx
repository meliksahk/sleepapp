import type { AdminUser } from './types';

/** Kullanıcı arama sonuç tablosu (docs/03 A2 destek). Salt okuma — mutasyon yok. */
export function UserTable({ users }: { users: AdminUser[] }) {
  if (users.length === 0) {
    return <p className="text-body text-ink-secondary">Eşleşen kullanıcı yok.</p>;
  }
  return (
    <table className="w-full text-body">
      <thead>
        <tr className="border-b border-ink-faint/20 text-left text-ink-secondary">
          <th className="py-2 pr-4 font-normal">E-posta</th>
          <th className="py-2 pr-4 font-normal">Tür</th>
          <th className="py-2 pr-4 font-normal">Oluşturma</th>
          <th className="py-2 font-normal">Kimlik</th>
        </tr>
      </thead>
      <tbody>
        {users.map((u) => (
          <tr key={u.id} className="border-b border-ink-faint/10">
            <td className="py-2 pr-4">{u.email ?? '—'}</td>
            <td className="py-2 pr-4">{u.kind}</td>
            <td className="py-2 pr-4">{new Date(u.createdAt).toISOString().slice(0, 10)}</td>
            <td className="py-2 font-mono text-caption text-ink-secondary">{u.id}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
