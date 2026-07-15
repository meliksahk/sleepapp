export interface StatCardProps {
  label: string;
  value: string;
  hint?: string;
}

/** Metrik kutusu — sayısal veri tabular-nums (docs/06). */
export function StatCard({ label, value, hint }: StatCardProps) {
  return (
    <div className="rounded-card bg-bg-raised p-4">
      <p className="text-caption text-ink-secondary">{label}</p>
      <p className="mt-1 text-h1 font-display tabular-nums text-ink-primary">{value}</p>
      {hint ? <p className="mt-1 text-caption text-ink-faint">{hint}</p> : null}
    </div>
  );
}
