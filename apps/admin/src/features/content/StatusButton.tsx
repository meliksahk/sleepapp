'use client';

import { useActionState } from 'react';
import { Button } from '@nocta/ui';
import { useT } from '@/shared/i18n/I18nProvider';
import { setStatusAction, type StatusState } from './actions';
import type { SoundscapeStatus } from './types';

const INITIAL: StatusState = {};

/** Yayınla / yayından kaldır düğmesi (satır başına). */
export function StatusButton({ slug, status }: { slug: string; status: SoundscapeStatus }) {
  const t = useT();
  const [state, action, pending] = useActionState(setStatusAction, INITIAL);
  const isPublished = status === 'published';

  return (
    <form action={action} className="flex flex-col items-start gap-1">
      <input type="hidden" name="slug" value={slug} />
      <input type="hidden" name="action" value={isPublished ? 'unpublish' : 'publish'} />
      <Button
        type="submit"
        variant={isPublished ? 'ghost' : 'primary'}
        disabled={pending}
        key={`status-${slug}`}
      >
        {pending ? '…' : isPublished ? t('content.unpublish') : t('content.publish')}
      </Button>
      {state.error !== undefined && (
        <span role="alert" className="text-caption text-accent-ember">
          {t(state.error)}
        </span>
      )}
    </form>
  );
}
