'use client';

import { useActionState } from 'react';
import { Button, Input } from '@nocta/ui';
import { useT } from '@/shared/i18n/I18nProvider';
import { createSoundscapeAction, type CreateState } from './actions';

const INITIAL: CreateState = {};

/** Yeni taslak formu (docs/03 A1). Yalnızca yazma yetkisi olan rollere gösterilir. */
export function NewSoundscapeForm() {
  const t = useT();
  const [state, action, pending] = useActionState(createSoundscapeAction, INITIAL);

  return (
    <form action={action} className="flex flex-col gap-3 md:max-w-md">
      <Input
        name="slug"
        label={t('content.fieldSlug')}
        placeholder={t('content.placeholderSlug')}
        required
      />
      <Input
        name="titleEn"
        label={t('content.fieldTitleEn')}
        placeholder={t('content.placeholderTitle')}
        required
      />
      <Input
        name="archetypeAffinity"
        label={t('content.fieldAffinity')}
        placeholder={t('content.placeholderAffinity')}
      />

      {state.error !== undefined && (
        <p role="alert" className="text-body text-accent-ember">
          {t(state.error)}
        </p>
      )}
      {state.createdSlug !== undefined && (
        <p role="status" className="text-body text-accent-aurora">
          {t('content.created', { slug: state.createdSlug })}
        </p>
      )}

      <Button type="submit" disabled={pending}>
        {pending ? t('common.saving') : t('content.createSubmit')}
      </Button>
    </form>
  );
}
