import type { ReactNode } from 'react';

export interface EmptyStateProps {
  title: string;
  description?: string;
  action?: ReactNode;
}

/** Boş liste durumu — her liste ekranı EmptyState/Error/Skeleton üçlüsünü kullanır (docs/03). */
export function EmptyState({ title, description, action }: EmptyStateProps) {
  return (
    <div
      role="status"
      className="rounded-card border border-ink-faint/20 p-8 text-center text-ink-secondary"
    >
      <h3 className="text-h2 font-display text-ink-primary">{title}</h3>
      {description ? <p className="mt-2 text-body">{description}</p> : null}
      {action ? <div className="mt-4 flex justify-center">{action}</div> : null}
    </div>
  );
}
