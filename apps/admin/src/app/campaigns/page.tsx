import { AppShell } from '@/shared/ui/AppShell';
import { apiGet } from '@/shared/api/server-client';
import { LogoutButton } from '@/features/auth/LogoutButton';
import { CampaignForm } from '@/features/campaigns/CampaignForm';
import { canSendCampaigns } from '@/features/campaigns/can-send-campaigns';
import { translator } from '@/shared/i18n/dictionaries';
import { getLocale } from '@/shared/i18n/locale';

/**
 * Push kampanyaları (docs/03 A5). Sunucu bileşeni: rol `/v1/admin/me`den okunur.
 * Kampanya gönderme yalnızca owner'a — form owner'a gösterilir, gerçek kapı sunucuda
 * (#183 → 403). Diğer roller için bölüm gizli + uyarı ("yalnızca UI gizleme yeterli
 * değil" §3.3 — sunucu ÖNCE 403 verir).
 */
export default async function CampaignsPage() {
  const locale = await getLocale();
  const t = translator(locale);
  const me = await apiGet<{ userId: string; roles: string[] }>('/v1/admin/me');
  const canSend = canSendCampaigns(me.roles);

  return (
    <AppShell actions={<LogoutButton />}>
      <h2 className="text-h2 font-display">{t('campaign.title')}</h2>
      <p className="mt-1 mb-6 text-body text-ink-secondary">
        {t('campaign.subtitle')}
        {canSend ? '' : ` ${t('campaign.subtitleNoPermission')}`}
      </p>

      {canSend ? (
        <CampaignForm />
      ) : (
        <p className="text-body text-ink-secondary">{t('campaign.noPermission')}</p>
      )}
    </AppShell>
  );
}
