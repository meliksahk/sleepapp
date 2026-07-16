import { LoginForm } from '@/features/auth/LoginForm';
import { safeNextPath } from '@/features/auth/safe-next';

/** Giriş sayfası — middleware matcher'ı bu yolu DIŞARIDA bırakır (sonsuz döngü olmasın). */
export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ next?: string }>;
}) {
  const { next } = await searchParams;
  const target = safeNextPath(next);

  return (
    <main className="flex min-h-screen flex-col items-center justify-center bg-bg-base p-6">
      <h1 className="mb-1 text-h1 font-display text-ink-primary">NOCTA</h1>
      <p className="mb-8 text-body text-ink-secondary">Yönetim paneli</p>
      <LoginForm next={target} />
    </main>
  );
}
