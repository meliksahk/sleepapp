import Link from 'next/link';
import { StatCard, Button } from '@nocta/ui';
import { AppShell } from '@/shared/ui/AppShell';
import { apiGet } from '@/shared/api/server-client';
import { LogoutButton } from '@/features/auth/LogoutButton';
import { translator } from '@/shared/i18n/dictionaries';
import { getLocale } from '@/shared/i18n/locale';
import { shareRateLabel, shareRateHint } from './share-rate';
import { AuditFeed, type AuditEntry } from './AuditFeed';

interface Overview {
  soundscapes: { draft: number; scheduled: number; published: number };
  waitlist: number;
  pushAudience: number;
  shareFunnel: { completed: number; shared: number; rate: number | null };
}

/**
 * Dashboard (docs/03). Rakamlar CANLI — ama yalnızca bugün DOĞRU hesaplanabilenler.
 *
 * D7 retention kohort analizi ister; deneme→ücretli billing'e (F6) bağlı. İkisi için
 * uydurma sayı göstermektense yer tutucu kalıyor: YANLIŞ bir metrik, OLMAYAN bir
 * metrikten daha kötüdür — insan ona güvenip karar verir.
 *
 * "Son etkinlik" #126'da KALDIRILMIŞTI (audit_log yoktu → hiç dolmayacak boş bir söz);
 * #134'te iz gelince GERİ EKLENDİ — bu kez gerçek veriyle.
 */
export async function DashboardPage() {
  const locale = await getLocale();
  const t = translator(locale);

  // Paralel: iki bağımsız okuma, biri diğerini beklemesin.
  const [o, audit] = await Promise.all([
    apiGet<Overview>('/v1/admin/overview'),
    apiGet<AuditEntry[]>('/v1/admin/audit'),
  ]);
  const total = o.soundscapes.published + o.soundscapes.draft + o.soundscapes.scheduled;

  return (
    <AppShell actions={<LogoutButton />}>
      <h2 className="text-h2 font-display">{t('dashboard.title')}</h2>
      <p className="mt-1 mb-5 text-body text-ink-secondary">{t('dashboard.subtitle')}</p>

      <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
        <StatCard
          label={t('dashboard.published')}
          value={String(o.soundscapes.published)}
          hint={t('dashboard.publishedHint')}
        />
        <StatCard
          label={t('dashboard.draft')}
          value={String(o.soundscapes.draft)}
          hint={t('dashboard.draftHint')}
        />
        <StatCard
          label={t('dashboard.waitlist')}
          value={String(o.waitlist)}
          hint={t('dashboard.waitlistHint')}
        />
        <StatCard
          label={t('dashboard.pushAudience')}
          value={String(o.pushAudience)}
          hint={t('dashboard.pushAudienceHint')}
        />
        {/* Viral kancanın sağlığı (CLAUDE.md §1.1: "viral kancalar süs değil
            çekirdek özelliktir"). Ürünün bahsi buysa ölçülmeli. */}
        <StatCard
          label={t('dashboard.shareRate')}
          value={shareRateLabel(locale, o.shareFunnel.rate)}
          hint={shareRateHint(locale, o.shareFunnel.completed, o.shareFunnel.shared)}
        />
        {/* Sahte sayı YOK: ölçülemeyeni ölçülüyormuş gibi göstermek, insanın ona
            güvenip yanlış karar vermesi demektir. */}
        <StatCard
          label={t('dashboard.trialToPaid')}
          value="—"
          hint={t('dashboard.trialToPaidHint')}
        />
      </div>

      <section className="mt-8">
        <h3 className="text-body font-display">{t('dashboard.soundscapes')}</h3>
        <p className="mt-1 mb-3 text-body text-ink-secondary">
          {t('dashboard.soundscapeCounts', { total, scheduled: o.soundscapes.scheduled })}
        </p>
        <Link href="/content">
          <Button>{t('dashboard.manageContent')}</Button>
        </Link>
      </section>

      <section className="mt-8">
        <h3 className="mb-3 text-body font-display">{t('dashboard.recentActivity')}</h3>
        <AuditFeed entries={audit} locale={locale} />
      </section>

      <section className="mt-8">
        <h3 className="text-body font-display">{t('dashboard.notMeasured')}</h3>
        <p className="mt-1 text-body text-ink-secondary">{t('dashboard.notMeasuredBody')}</p>
      </section>
    </AppShell>
  );
}
