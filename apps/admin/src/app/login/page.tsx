import { LoginForm } from '@/features/auth/LoginForm';
import { safeNextPath } from '@/features/auth/safe-next';
import { translate } from '@/shared/i18n/dictionaries';
import { LocaleSwitcher } from '@/shared/i18n/LocaleSwitcher';
import { getLocale } from '@/shared/i18n/locale';

/**
 * Giriş sayfası — middleware matcher'ı bu yolu DIŞARIDA bırakır (sonsuz döngü olmasın).
 *
 * Dil seçici burada da var: AppShell kullanılmadığı için otomatik gelmiyordu ve GİRİŞ
 * YAPMAMIŞ kullanıcı dili hiç seçemiyordu — panelin ilk ekranı, dilin en çok gerektiği yer.
 */
export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ next?: string }>;
}) {
  const locale = await getLocale();
  const { next } = await searchParams;
  const target = safeNextPath(next);

  return (
    <main className="flex min-h-screen flex-col items-center justify-center bg-bg-base p-6">
      <div className="absolute top-4 right-4">
        <LocaleSwitcher />
      </div>
      <h1 className="mb-1 text-h1 font-display text-ink-primary">NOCTA</h1>
      <p className="mb-8 text-body text-ink-secondary">{translate(locale, 'login.subtitle')}</p>
      <LoginForm next={target} />
    </main>
  );
}
