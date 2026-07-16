'use client';

import { useActionState } from 'react';
import { Button, Input } from '@nocta/ui';
import { updateMetaAction, type MetaState } from './actions';

const INITIAL: MetaState = {};

/**
 * Başlık / uyku kimliği düzenleme.
 *
 * SLUG ALANI YOK ve olmayacak: derin linkte yaşar (`/a/{slug}`) ve paylaşılan
 * kartlarda dolaşır — düzenlenebilir göstermek, kırılacak bir söz vermek olurdu.
 */
export function MetaForm({
  slug,
  title,
  affinity,
}: {
  slug: string;
  title: string;
  affinity: string[];
}) {
  const [state, action, pending] = useActionState(updateMetaAction, INITIAL);

  return (
    <form action={action} className="flex flex-col gap-3 md:max-w-md">
      <input type="hidden" name="slug" value={slug} />
      <Input name="titleEn" label="Başlık (EN)" defaultValue={title} required />
      <Input
        name="archetypeAffinity"
        label="Uyku kimlikleri (virgülle)"
        defaultValue={affinity.join(', ')}
      />
      {state.error !== undefined && (
        <p role="alert" className="text-body text-accent-ember">
          {state.error}
        </p>
      )}
      {state.saved === true && (
        <p role="status" className="text-body text-accent-aurora">
          Kaydedildi.
        </p>
      )}
      <Button type="submit" disabled={pending}>
        {pending ? 'Kaydediliyor…' : 'Bilgileri kaydet'}
      </Button>
    </form>
  );
}
