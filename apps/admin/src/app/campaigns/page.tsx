import { AppShell } from '@/shared/ui/AppShell';
import { apiGet } from '@/shared/api/server-client';
import { LogoutButton } from '@/features/auth/LogoutButton';
import { CampaignForm } from '@/features/campaigns/CampaignForm';
import { canSendCampaigns } from '@/features/campaigns/can-send-campaigns';

/**
 * Push kampanyaları (docs/03 A5). Sunucu bileşeni: rol `/v1/admin/me`den okunur.
 * Kampanya gönderme yalnızca owner'a — form owner'a gösterilir, gerçek kapı sunucuda
 * (#183 → 403). Diğer roller için bölüm gizli + uyarı ("yalnızca UI gizleme yeterli
 * değil" §3.3 — sunucu ÖNCE 403 verir).
 */
export default async function CampaignsPage() {
  const me = await apiGet<{ userId: string; roles: string[] }>('/v1/admin/me');
  const canSend = canSendCampaigns(me.roles);

  return (
    <AppShell actions={<LogoutButton />}>
      <h2 className="text-h2 font-display">Push Campaigns</h2>
      <p className="mt-1 mb-6 text-body text-ink-secondary">
        Push token&apos;ı olan kullanıcılara bildirim gönder.
        {canSend ? '' : ' Gönderme yetkisi yalnızca owner rolündedir.'}
      </p>

      {canSend ? (
        <CampaignForm />
      ) : (
        <p className="text-body text-ink-secondary">
          Kampanya göndermek için owner yetkisi gerekir.
        </p>
      )}
    </AppShell>
  );
}
