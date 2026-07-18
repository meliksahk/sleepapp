'use client';

import { createContext, useContext, type ReactNode } from 'react';

import { translate, type Locale, type MessageKey } from './dictionaries';

const LocaleContext = createContext<Locale>('tr');

/** Sunucu layout'u aktif dili buradan istemci ağacına indirir. */
export function I18nProvider({ locale, children }: { locale: Locale; children: ReactNode }) {
  return <LocaleContext.Provider value={locale}>{children}</LocaleContext.Provider>;
}

/** İstemci bileşenleri için çeviri fonksiyonu. */
export function useT(): (key: MessageKey, vars?: Record<string, string | number>) => string {
  const locale = useContext(LocaleContext);
  return (key, vars) => translate(locale, key, vars);
}

export function useLocale(): Locale {
  return useContext(LocaleContext);
}
