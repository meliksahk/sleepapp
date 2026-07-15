import type { ReactNode } from 'react';
import { EmptyState } from './empty-state';

export interface Column<T> {
  key: string;
  header: string;
  /** Özel hücre render; yoksa row[key] string olarak gösterilir. */
  render?: (row: T) => ReactNode;
}

export interface DataTableProps<T extends { id: string }> {
  columns: ReadonlyArray<Column<T>>;
  rows: ReadonlyArray<T>;
  emptyTitle?: string;
}

/** Genelleştirilmiş tablo (docs/03 §1.1). Boşsa EmptyState; iş mantığı/API yok. */
export function DataTable<T extends { id: string }>({
  columns,
  rows,
  emptyTitle = 'Kayıt yok',
}: DataTableProps<T>) {
  if (rows.length === 0) {
    return <EmptyState title={emptyTitle} />;
  }
  return (
    <table className="w-full border-collapse text-body">
      <thead>
        <tr className="border-b border-ink-faint/20 text-left text-ink-secondary">
          {columns.map((c) => (
            <th key={c.key} className="px-3 py-2 text-caption font-medium">
              {c.header}
            </th>
          ))}
        </tr>
      </thead>
      <tbody>
        {rows.map((row) => (
          <tr key={row.id} className="border-b border-ink-faint/10">
            {columns.map((c) => (
              <td key={c.key} className="px-3 py-2 text-ink-primary">
                {c.render ? c.render(row) : String((row as Record<string, unknown>)[c.key] ?? '')}
              </td>
            ))}
          </tr>
        ))}
      </tbody>
    </table>
  );
}
