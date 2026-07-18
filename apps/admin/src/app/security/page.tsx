import { apiGet } from '@/shared/api/server-client';
import { TotpSetup } from '@/features/security/TotpSetup';
import { TotpReset } from '@/features/security/TotpReset';
import { translator, type Locale } from '@/shared/i18n/dictionaries';
import { LocaleSwitcher } from '@/shared/i18n/LocaleSwitcher';
import { getLocale } from '@/shared/i18n/locale';

interface TotpStatus {
  enabled: boolean;
  pending: boolean;
}

/**
 * Hesap güvenliği — 2FA kurulumu (docs/03 A0, CLAUDE.md §3.3).
 *
 * Durum SUNUCUDAN okunur: "2FA etkin mi" sorusunun cevabı istemcide tutulamaz —
 * tarayıcıdaki bir bayrak, kapalı 2FA'yı "açık" gösterebilirdi.
 *
 * Bu sayfa AppShell KULLANMIYOR (odaklı, tek işlik ekran) — bu yüzden dil seçici
 * elle konuluyor; yoksa buraya gelen kullanıcı dili değiştiremezdi.
 */
export default async function SecurityPage() {
  const locale = await getLocale();
  const t = translator(locale);
  const status = await apiGet<TotpStatus>('/v1/auth/admin/totp');

  return (
    <main className="mx-auto flex max-w-xl flex-col gap-8 p-8">
      <header className="flex flex-col gap-2">
        <div className="flex items-start justify-between gap-4">
          <h1 className="text-title">{t('security.title')}</h1>
          <LocaleSwitcher />
        </div>
        <p className="text-body text-ink-muted">{t('security.subtitle')}</p>
      </header>

      <section className="flex flex-col gap-4">
        <div className="flex items-center gap-3">
          <h2 className="text-subtitle">{t('security.twoStep')}</h2>
          <StatusBadge status={status} locale={locale} />
        </div>

        {status.enabled ? (
          <div className="flex flex-col gap-4">
            <p className="text-body text-ink-muted">{t('security.enabledBody')}</p>
            {/* Dürüstlük: GİRİŞ YAPMIŞKEN cihaz rotasyonu artık mümkün (#186, aşağıda),
                ama telefonu kaybedip ÇIKIŞ yapmışken hâlâ kurtarma yok (yedek kod akışı
                D-11). Kullanıcının bunu ÖNCEDEN bilmesi gerekir. */}
            <p className="text-caption text-accent-ember">{t('security.recoveryWarning')}</p>

            <div className="border-t border-ink-faint/20 pt-4">
              <h3 className="text-body font-display">{t('security.rotateHeading')}</h3>
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

function StatusBadge({ status, locale }: { status: TotpStatus; locale: Locale }) {
  const t = translator(locale);
  if (status.enabled) {
    return (
      <span className="text-caption text-accent-sage rounded-full border px-2 py-0.5">
        {t('security.badgeEnabled')}
      </span>
    );
  }
  // "Yarıda kalmış" ayrı gösterilir: "kapalı" demek kullanıcının neden yeniden
  // başlattığını açıklamazdı.
  if (status.pending) {
    return (
      <span className="text-caption text-ink-muted rounded-full border px-2 py-0.5">
        {t('security.badgePending')}
      </span>
    );
  }
  return (
    <span className="text-caption text-ink-muted rounded-full border px-2 py-0.5">
      {t('security.badgeOff')}
    </span>
  );
}
