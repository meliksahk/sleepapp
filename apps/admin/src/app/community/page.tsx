import { AppShell } from '@/shared/ui/AppShell';
import { apiGet } from '@/shared/api/server-client';
import { LogoutButton } from '@/features/auth/LogoutButton';
import { canModerateCommunity, type AdminCommunitySound } from '@/features/community/types';
import { ModerationRow } from '@/features/community/ModerationRow';
import { translator } from '@/shared/i18n/dictionaries';
import { getLocale } from '@/shared/i18n/locale';

/**
 * Topluluk moderasyonu (3a). Sunucu bileşeni: durum filtresi `?status=` ile
 * SSR yapılır; satır eylemleri Server Action üzerinden API'ye gider.
 *
 * **Rol görünürlüğü:** owner/editor. Gerçek kapı API @Roles'tadır — bu sayfa
 * yalnızca gereksiz 403 denemeyi önler ("UI gizleme yeterli değil", §3.3).
 *
 * VARSAYILAN (bilinçli): sesi DİNLEMEK bu iterasyonda yok — moderatör meta
 * (başlık/süre/boyut) ile karar verir. Dosya önizlemesi ayrı iş (MinIO'dan
 * kısa ömürlü URL + <audio>; 3b'de keşif akışıyla birlikte).
 */
export default async function CommunityPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string }>;
}) {
  const locale = await getLocale();
  const t = translator(locale);
  const { status } = await searchParams;
  const resolved =
    status === 'approved' || status === 'rejected' || status === 'pending' ? status : 'pending';

  const me = await apiGet<{ userId: string; roles: string[] }>('/v1/admin/me');
  if (!canModerateCommunity(me.roles)) {
    return (
      <AppShell actions={<LogoutButton />}>
        <h2 className="text-h2 font-display">{t('community.title')}</h2>
        <p className="mt-2 text-body text-ink-secondary">{t('community.noPermission')}</p>
      </AppShell>
    );
  }

  let items: AdminCommunitySound[] = [];
  let loadError: string | null = null;
  try {
    items = await apiGet<AdminCommunitySound[]>(`/v1/admin/community-sounds?status=${resolved}`);
  } catch {
    loadError = t('community.loadFailed');
  }

  // Önizleme URL'leri SUNUCUDA üretilir (presigned; token çerezi tarayıcıya
  // gitmez) ve satıra hazır geçilir. URL üretimi offline imzadır — N+1 ağ
  // çağrısı değil; tek liste sayfasında onlarca imza milisaniyelik iş.
  const previewUrls: Record<string, string> = {};
  for (const item of items) {
    try {
      const p = await apiGet<{ url: string }>(
        `/v1/admin/community-sounds/${encodeURIComponent(item.id)}/file`,
      );
      previewUrls[item.id] = p.url;
    } catch {
      // Tek bir önizleme patlarsa LİSTE ÖLMEZ: o satırda dinleme düğmesi olmaz.
    }
  }

  const tabs: Array<{ key: 'pending' | 'approved' | 'rejected'; label: string }> = [
    { key: 'pending', label: t('community.tabPending') },
    { key: 'approved', label: t('community.tabApproved') },
    { key: 'rejected', label: t('community.tabRejected') },
  ];

  return (
    <AppShell actions={<LogoutButton />}>
      <h2 className="text-h2 font-display">{t('community.title')}</h2>
      <p className="mt-1 mb-4 text-body text-ink-secondary">{t('community.subtitle')}</p>

      <nav aria-label={t('community.filterLabel')} className="mb-4 flex gap-2">
        {tabs.map((tab) => (
          <a
            key={tab.key}
            href={`/community?status=${tab.key}`}
            aria-current={resolved === tab.key ? 'page' : undefined}
            className={`rounded-chip px-3 py-1.5 text-caption ${
              resolved === tab.key
                ? 'bg-accent-aurora text-bg-base'
                : 'border border-ink-faint/40 text-ink-secondary'
            }`}
          >
            {tab.label}
          </a>
        ))}
      </nav>

      {loadError && (
        <p role="alert" className="text-body text-accent-ember">
          {loadError}
        </p>
      )}
      {!loadError && items.length === 0 && (
        <p className="text-body text-ink-secondary">{t('community.empty')}</p>
      )}
      {items.length > 0 && (
        <ul>
          {items.map((sound) => (
            // Reddedilenler/arşiv yalnızca bilgi: karar butonları pending'de anlamlı,
            // ama approved→rejected geri çekme de ModerationRow'dan yapılabilir —
            // o yüzden liste her durumda aynı satır bileşenini kullanır.
            <ModerationRow key={sound.id} sound={sound} previewUrl={previewUrls[sound.id]} />
          ))}
        </ul>
      )}
    </AppShell>
  );
}
