import { AppShell } from '@/shared/ui/AppShell';
import { LogoutButton } from '@/features/auth/LogoutButton';
import { translator, type MessageKey } from '@/shared/i18n/dictionaries';
import { getLocale } from '@/shared/i18n/locale';
import {
  FREE_LIBRARY_SIZE,
  FREE_MIX_SLOTS,
  PREMIUM_FEATURES,
  TRIAL_DAYS,
} from '@/features/plan/premium-plan';

/**
 * **Plan (ödeme çerçevesi) — SALT OKUNUR** (F5).
 *
 * Panelde "hangi özellik premium" sorusunun tek görünür cevabı. Düzenlenebilir
 * DEĞİL ve bu bilinçli: sınır bugün kodda (mobil + bu kopya) yaşıyor, bir DB
 * ayarında değil. Düzenlenebilir yapmak, arkasında hiçbir şeyi değiştirmeyen bir
 * form üretirdi — editör kaydeder, hiçbir kullanıcıda hiçbir şey değişmez.
 *
 * Sayfanın en önemli cümlesi uyarı bloğu: ödeme BAĞLI DEĞİL, herkes premium
 * görüyor. Bunu yazmayan bir panel, ekibi kendi ürünü hakkında yanıltır.
 */
export default async function PlanPage() {
  const locale = await getLocale();
  const t = translator(locale);

  return (
    <AppShell actions={<LogoutButton />}>
      <h2 className="text-h2 font-display">{t('plan.title')}</h2>
      <p className="mt-1 mb-6 text-body text-ink-secondary">{t('plan.subtitle')}</p>

      <div
        data-testid="plan-not-connected"
        className="mb-8 border border-danger/40 bg-danger/10 p-4 text-body"
      >
        {t('plan.notConnected')}
      </div>

      <section className="mb-8">
        <h3 className="mb-2 text-body font-display">{t('plan.freeHeading')}</h3>
        <ul className="list-disc pl-5 text-body text-ink-secondary">
          <li>{t('plan.freeMixer')}</li>
          <li>{t('plan.freeRecordings')}</li>
          <li>{t('plan.freeLibrary', { count: FREE_LIBRARY_SIZE })}</li>
          <li>{t('plan.freeMixes', { count: FREE_MIX_SLOTS })}</li>
        </ul>
      </section>

      <section className="mb-8">
        <h3 className="mb-2 text-body font-display">{t('plan.premiumHeading')}</h3>
        <ul className="list-disc pl-5 text-body text-ink-secondary">
          {PREMIUM_FEATURES.map((f) => (
            <li key={f} data-testid={`plan-feature-${f}`}>
              {t(`plan.feature.${f}` as MessageKey)}
            </li>
          ))}
        </ul>
      </section>

      <section>
        <h3 className="mb-2 text-body font-display">{t('plan.trialHeading')}</h3>
        <p className="text-body text-ink-secondary">{t('plan.trialBody', { days: TRIAL_DAYS })}</p>
      </section>
    </AppShell>
  );
}
