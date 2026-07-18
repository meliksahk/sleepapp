'use client';

import { useActionState } from 'react';
import { Button, Input } from '@nocta/ui';
import { upsertFlagAction, type UpsertFlagState } from './actions';

const INITIAL: UpsertFlagState = {};

/**
 * Flag oluştur/değiştir formu (owner-only, docs/03 A4). Tek form hem yeni flag açar
 * hem mevcut anahtarı üzerine yazar (upsert). Doğrulama sunucuda (#167); form yalnızca
 * reddi gösterir. Kapalı = hiç kimseye gitmez; yüzde boş = herkes.
 */
export function FlagForm() {
  const [state, action, pending] = useActionState(upsertFlagAction, INITIAL);

  return (
    <form action={action} className="mt-4 flex flex-col gap-3 md:max-w-md">
      <Input
        name="key"
        label="Anahtar (küçük-harf-kebab, ör. smart-alarm)"
        placeholder="smart-alarm"
        required
      />

      <label className="flex flex-col gap-1">
        <span className="text-caption text-ink-secondary">Durum</span>
        <select
          name="enabled"
          defaultValue="false"
          className="rounded-button bg-bg-raised px-4 py-2 text-ink-primary"
        >
          <option value="true">Açık</option>
          <option value="false">Kapalı</option>
        </select>
      </label>

      <Input
        name="rolloutPercentage"
        label="Rollout % (boş = herkes)"
        type="number"
        min={0}
        max={100}
        placeholder="ör. 25"
      />
      <Input
        name="platforms"
        label="Platformlar (virgülle, boş = hepsi)"
        placeholder="ios, android"
      />
      <Input name="minAppVersion" label="Asgari sürüm (boş = yok)" placeholder="1.4.0" />

      {state.error !== undefined && (
        <p role="alert" className="text-body text-accent-ember">
          {state.error}
        </p>
      )}
      {state.savedKey !== undefined && (
        <p role="status" className="text-body text-accent-aurora">
          “{state.savedKey}” kaydedildi.
        </p>
      )}

      <Button type="submit" disabled={pending}>
        {pending ? 'Kaydediliyor…' : 'Flag kaydet'}
      </Button>
    </form>
  );
}
