'use client';

import { useState } from 'react';
import { t, type Locale } from '@/lib/i18n';

/**
 * Paylaşım butonu — Web Share API (mobil OS paylaşım sayfası) varsa onu kullanır,
 * yoksa link'i panoya kopyalar (masaüstü fallback). Viral kanca (docs/05).
 */
export function ShareButton({
  title,
  url,
  locale = 'en',
}: {
  title: string;
  url: string;
  locale?: Locale;
}) {
  const [copied, setCopied] = useState(false);

  async function onShare(): Promise<void> {
    const nav = navigator as Navigator & { share?: (data: ShareData) => Promise<void> };
    if (typeof nav.share === 'function') {
      // İptal/başarısızlıkta panoya düş.
      const shared = await nav.share({ title, url }).then(
        () => true,
        () => false,
      );
      if (shared) return;
    }
    const ok = await navigator.clipboard.writeText(url).then(
      () => true,
      () => false,
    );
    if (ok) setCopied(true);
  }

  return (
    <button
      type="button"
      onClick={onShare}
      className="inline-block rounded-button border border-ink-faint/40 px-5 py-3 text-ink-primary"
    >
      {copied ? t(locale, 'share.copied') : t(locale, 'share.action')}
    </button>
  );
}
