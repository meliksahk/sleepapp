'use client';

import { useActionState } from 'react';
import { Button, Input } from '@nocta/ui';
import { createSoundscapeAction, type CreateState } from './actions';

const INITIAL: CreateState = {};

/** Yeni taslak formu (docs/03 A1). Yalnızca yazma yetkisi olan rollere gösterilir. */
export function NewSoundscapeForm() {
  const [state, action, pending] = useActionState(createSoundscapeAction, INITIAL);

  return (
    <form action={action} className="flex flex-col gap-3 md:max-w-md">
      <Input name="slug" label="Slug" placeholder="deep-ocean-drift" required />
      <Input name="titleEn" label="Başlık (EN)" placeholder="Deep Ocean Drift" required />
      <Input
        name="archetypeAffinity"
        label="Uyku kimlikleri (virgülle)"
        placeholder="deep-ocean, night-owl"
      />

      {state.error !== undefined && (
        <p role="alert" className="text-body text-accent-ember">
          {state.error}
        </p>
      )}
      {state.createdSlug !== undefined && (
        <p role="status" className="text-body text-accent-aurora">
          Taslak oluşturuldu: {state.createdSlug}
        </p>
      )}

      <Button type="submit" disabled={pending}>
        {pending ? 'Kaydediliyor…' : 'Taslak oluştur'}
      </Button>
    </form>
  );
}
