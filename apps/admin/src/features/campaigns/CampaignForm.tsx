'use client';

import { useActionState } from 'react';
import { Button, Input } from '@nocta/ui';
import { sendCampaignAction, type SendCampaignState } from './actions';
import { useT } from '@/shared/i18n/I18nProvider';

const INITIAL: SendCampaignState = {};

/**
 * Push kampanyası besteleme formu (owner-only, docs/03 A5). Gönderim TÜM push
 * kullanıcılarına ulaşır (opt-out yapanlar hariç); reach UI'da açıkça belirtilir ki
 * owner ne yaptığını bilerek göndersin. Doğrulama sunucuda (#183); form reddi + sonucu gösterir.
 */
export function CampaignForm() {
  const t = useT();
  const [state, action, pending] = useActionState(sendCampaignAction, INITIAL);

  return (
    <form action={action} className="mt-4 flex flex-col gap-3 md:max-w-md">
      <Input
        name="title"
        label="Başlık"
        placeholder="Yeni haftalık soundscape"
        required
        maxLength={80}
      />

      <label className="flex flex-col gap-1">
        <span className="text-caption text-ink-secondary">Gövde</span>
        <textarea
          name="body"
          required
          maxLength={240}
          rows={3}
          placeholder="Bu haftanın ritüel sesi yayında."
          className="rounded-button bg-bg-raised px-4 py-2 text-ink-primary"
        />
      </label>

      <label className="flex flex-col gap-1">
        <span className="text-caption text-ink-secondary">Hedef</span>
        <select
          name="platform"
          defaultValue=""
          className="rounded-button bg-bg-raised px-4 py-2 text-ink-primary"
        >
          <option value="">Tüm push kullanıcıları</option>
          <option value="ios">Yalnızca iOS</option>
          <option value="android">Yalnızca Android</option>
        </select>
      </label>

      <p className="text-caption text-ink-secondary">
        Gönderim seçili segmentteki tüm kullanıcılara ulaşır (bildirimleri kapatanlar hariç).
      </p>

      {state.error !== undefined && (
        <p role="alert" className="text-body text-accent-ember">
          {state.error}
        </p>
      )}
      {state.result !== undefined && (
        <p role="status" className="text-body text-accent-aurora">
          {t('campaign.queued', {
            recipients: state.result.recipients,
            queued: state.result.queued,
          })}
        </p>
      )}

      <Button type="submit" disabled={pending}>
        {pending ? t('campaign.submitting') : t('campaign.submit')}
      </Button>
    </form>
  );
}
