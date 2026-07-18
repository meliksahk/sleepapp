'use client';

import { useActionState } from 'react';
import { Button, Input } from '@nocta/ui';
import { useT } from '@/shared/i18n/I18nProvider';
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
  const t = useT();
  const [state, action, pending] = useActionState(updateMetaAction, INITIAL);

  return (
    <form action={action} className="flex flex-col gap-3 md:max-w-md">
      <input type="hidden" name="slug" value={slug} />
      <Input name="titleEn" label={t('content.fieldTitleEn')} defaultValue={title} required />
      <Input
        name="archetypeAffinity"
        label={t('content.fieldAffinity')}
        defaultValue={affinity.join(', ')}
      />
      {state.error !== undefined && (
        <p role="alert" className="text-body text-accent-ember">
          {t(state.error)}
        </p>
      )}
      {state.saved === true && (
        <p role="status" className="text-body text-accent-aurora">
          {t('common.saved')}
        </p>
      )}
      <Button type="submit" disabled={pending}>
        {pending ? t('common.saving') : t('content.metaSubmit')}
      </Button>
    </form>
  );
}
