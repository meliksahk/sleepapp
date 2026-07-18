'use client';

import { useTransition } from 'react';

import { setLocale } from './actions';
import { locales } from './dictionaries';
import { useLocale, useT } from './I18nProvider';

/** Panel dili değiştirici — AppShell'de. */
export function LocaleSwitcher() {
  const current = useLocale();
  const t = useT();
  const [pending, start] = useTransition();

  return (
    <label className="flex items-center gap-2 text-sm">
      <span className="sr-only">{t('lang.label')}</span>
      <select
        aria-label={t('lang.label')}
        className="rounded border bg-transparent px-2 py-1"
        value={current}
        disabled={pending}
        onChange={(e) => {
          const next = e.target.value;
          start(() => {
            void setLocale(next);
          });
        }}
      >
        {locales.map((l) => (
          <option key={l} value={l}>
            {t(l === 'tr' ? 'lang.tr' : 'lang.en')}
          </option>
        ))}
      </select>
    </label>
  );
}
