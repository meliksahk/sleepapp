import type { AdminFlag } from './types';
import { rolloutSummary } from './rollout-summary';

/**
 * Feature flag tablosu (docs/03 A4 rollout görünürlüğü). Salt okuma — düzenleme
 * (upsert) owner-kapılı ayrı iş. Her flag: durum rozeti (Açık/Kapalı) + hedefleme özeti.
 */
export function FlagTable({ flags }: { flags: AdminFlag[] }) {
  if (flags.length === 0) {
    return <p className="text-body text-ink-secondary">Tanımlı feature flag yok.</p>;
  }
  return (
    <table className="w-full text-body">
      <thead>
        <tr className="border-b border-ink-faint/20 text-left text-ink-secondary">
          <th className="py-2 pr-4 font-normal">Anahtar</th>
          <th className="py-2 pr-4 font-normal">Durum</th>
          <th className="py-2 font-normal">Hedefleme</th>
        </tr>
      </thead>
      <tbody>
        {flags.map((f) => (
          <tr key={f.key} className="border-b border-ink-faint/10">
            <td className="py-2 pr-4 font-mono text-caption">{f.key}</td>
            <td className="py-2 pr-4">
              {f.rules.enabled ? (
                <span className="rounded-chip bg-accent-aurora/20 px-2 py-0.5 text-caption text-accent-aurora">
                  Açık
                </span>
              ) : (
                <span className="rounded-chip bg-ink-faint/15 px-2 py-0.5 text-caption text-ink-secondary">
                  Kapalı
                </span>
              )}
            </td>
            <td className="py-2 text-ink-secondary">{rolloutSummary(f.rules)}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
