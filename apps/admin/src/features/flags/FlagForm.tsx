'use client';

import { useActionState } from 'react';
import { Button, Input } from '@nocta/ui';
import { useT } from '@/shared/i18n/I18nProvider';
import { upsertFlagAction, type UpsertFlagState } from './actions';

const INITIAL: UpsertFlagState = {};

/**
 * Flag oluştur/değiştir formu (owner-only, docs/03 A4). Tek form hem yeni flag açar
 * hem mevcut anahtarı üzerine yazar (upsert). Doğrulama sunucuda (#167); form yalnızca
 * reddi gösterir. Kapalı = hiç kimseye gitmez; yüzde boş = herkes.
 */
export function FlagForm() {
  const t = useT();
  const [state, action, pending] = useActionState(upsertFlagAction, INITIAL);

  return (
    <form action={action} className="mt-4 flex flex-col gap-3 md:max-w-md">
      <Input
        name="key"
        label={t('flags.fieldKey')}
        placeholder={t('flags.placeholderKey')}
        required
      />

      <label className="flex flex-col gap-1">
        <span className="text-caption text-ink-secondary">{t('flags.fieldStatus')}</span>
        <select
          name="enabled"
          defaultValue="false"
          className="rounded-button bg-bg-raised px-4 py-2 text-ink-primary"
        >
          <option value="true">{t('flags.on')}</option>
          <option value="false">{t('flags.off')}</option>
        </select>
      </label>

      <Input
        name="rolloutPercentage"
        label={t('flags.fieldRollout')}
        type="number"
        min={0}
        max={100}
        placeholder={t('flags.placeholderRollout')}
      />
      <Input
        name="platforms"
        label={t('flags.fieldPlatforms')}
        placeholder={t('flags.placeholderPlatforms')}
      />
      <Input
        name="minAppVersion"
        label={t('flags.fieldMinVersion')}
        placeholder={t('flags.placeholderVersion')}
      />

      {state.error !== undefined && (
        <p role="alert" className="text-body text-accent-ember">
          {t(state.error)}
        </p>
      )}
      {state.savedKey !== undefined && (
        <p role="status" className="text-body text-accent-aurora">
          {t('flags.savedKey', { key: state.savedKey })}
        </p>
      )}

      <Button type="submit" disabled={pending}>
        {pending ? t('common.saving') : t('flags.submit')}
      </Button>
    </form>
  );
}
