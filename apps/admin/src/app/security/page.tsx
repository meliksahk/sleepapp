import { apiGet } from '@/shared/api/server-client';
import { TotpSetup } from '@/features/security/TotpSetup';
import { TotpReset } from '@/features/security/TotpReset';

interface TotpStatus {
  enabled: boolean;
  pending: boolean;
}

/**
 * Hesap güvenliği — 2FA kurulumu (docs/03 A0, CLAUDE.md §3.3).
 *
 * Durum SUNUCUDAN okunur: "2FA etkin mi" sorusunun cevabı istemcide tutulamaz —
 * tarayıcıdaki bir bayrak, kapalı 2FA'yı "açık" gösterebilirdi.
 */
export default async function SecurityPage() {
  const status = await apiGet<TotpStatus>('/v1/auth/admin/totp');

  return (
    <main className="mx-auto flex max-w-xl flex-col gap-8 p-8">
      <header className="flex flex-col gap-2">
        <h1 className="text-title">Hesap güvenliği</h1>
        <p className="text-body text-ink-muted">
          İki adımlı doğrulama, parolanız ele geçse bile hesabınızı korur.
        </p>
      </header>

      <section className="flex flex-col gap-4">
        <div className="flex items-center gap-3">
          <h2 className="text-subtitle">İki adımlı doğrulama</h2>
          <StatusBadge status={status} />
        </div>

        {status.enabled ? (
          <div className="flex flex-col gap-4">
            <p className="text-body text-ink-muted">
              Her girişte doğrulama uygulamanızdaki kod istenir.
            </p>
            {/* Dürüstlük: GİRİŞ YAPMIŞKEN cihaz rotasyonu artık mümkün (#186, aşağıda),
                ama telefonu kaybedip ÇIKIŞ yapmışken hâlâ kurtarma yok (yedek kod akışı
                D-11). Kullanıcının bunu ÖNCEDEN bilmesi gerekir. */}
            <p className="text-caption text-accent-ember">
              Giriş yapmışken 2FA&apos;yı aşağıdan sıfırlayıp yeni cihaza taşıyabilirsiniz; ancak
              çıkış yapmışken doğrulama uygulamanızı kaybederseniz giriş yapamazsınız — kurulum
              anahtarını güvenli bir yerde saklayın.
            </p>

            <div className="border-t border-ink-faint/20 pt-4">
              <h3 className="text-body font-display">Yeni cihaza taşı / sıfırla</h3>
              <div className="mt-2">
                <TotpReset />
              </div>
            </div>
          </div>
        ) : (
          <TotpSetup />
        )}
      </section>
    </main>
  );
}

function StatusBadge({ status }: { status: TotpStatus }) {
  if (status.enabled) {
    return (
      <span className="text-caption text-accent-sage rounded-full border px-2 py-0.5">Etkin</span>
    );
  }
  // "Yarıda kalmış" ayrı gösterilir: "kapalı" demek kullanıcının neden yeniden
  // başlattığını açıklamazdı.
  if (status.pending) {
    return (
      <span className="text-caption text-ink-muted rounded-full border px-2 py-0.5">
        Kurulum tamamlanmadı
      </span>
    );
  }
  return (
    <span className="text-caption text-ink-muted rounded-full border px-2 py-0.5">Kapalı</span>
  );
}
