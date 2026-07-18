import { translate, type Locale } from '@/shared/i18n/dictionaries';
import type { AdminFlag } from './types';
import { rolloutSummary } from './rollout-summary';

/**
 * Feature flag tablosu (docs/03 A4 rollout görünürlüğü). Salt okuma — düzenleme
 * (upsert) owner-kapılı ayrı iş. Her flag: durum rozeti (Açık/Kapalı) + hedefleme özeti.
 *
 * Sunucu bileşeni: dil PROP olarak gelir (`useT()` bir hook, burada çağrılamaz).
 */
export function FlagTable({ flags, locale }: { flags: AdminFlag[]; locale: Locale }) {
  if (flags.length === 0) {
    return <p className="text-body text-ink-secondary">{translate(locale, 'flags.empty')}</p>;
  }
  return (
    <table className="w-full text-body">
      <thead>
        <tr className="border-b border-ink-faint/20 text-left text-ink-secondary">
          <th className="py-2 pr-4 font-normal">{translate(locale, 'flags.colKey')}</th>
          <th className="py-2 pr-4 font-normal">{translate(locale, 'flags.colStatus')}</th>
          <th className="py-2 font-normal">{translate(locale, 'flags.colTargeting')}</th>
        </tr>
      </thead>
      <tbody>
        {flags.map((f) => (
          <tr key={f.key} className="border-b border-ink-faint/10">
            <td className="py-2 pr-4 font-mono text-caption">{f.key}</td>
            <td className="py-2 pr-4">
              {f.rules.enabled ? (
                <span className="rounded-chip bg-accent-aurora/20 px-2 py-0.5 text-caption text-accent-aurora">
                  {translate(locale, 'flags.on')}
                </span>
              ) : (
                <span className="rounded-chip bg-ink-faint/15 px-2 py-0.5 text-caption text-ink-secondary">
                  {translate(locale, 'flags.off')}
                </span>
              )}
            </td>
            <td className="py-2 text-ink-secondary">{rolloutSummary(locale, f.rules)}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
