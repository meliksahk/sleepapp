import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { Input } from './input';
import { DataTable, type Column } from './data-table';
import { ConfirmDialog } from './confirm-dialog';

describe('Input', () => {
  it('label ile input ilişkilendirir ve hata gösterir', () => {
    render(<Input label="E-posta" error="Zorunlu" />);
    const input = screen.getByLabelText('E-posta');
    expect(input).toBeInTheDocument();
    expect(input).toHaveAttribute('aria-invalid', 'true');
    expect(screen.getByRole('alert')).toHaveTextContent('Zorunlu');
  });
});

interface Row {
  id: string;
  name: string;
  status: string;
}
const columns: Column<Row>[] = [
  { key: 'name', header: 'İsim' },
  { key: 'status', header: 'Durum', render: (r) => r.status.toUpperCase() },
];

describe('DataTable', () => {
  it('satırları ve özel render hücresini gösterir', () => {
    render(<DataTable columns={columns} rows={[{ id: '1', name: 'Rain', status: 'published' }]} />);
    expect(screen.getByText('Rain')).toBeInTheDocument();
    expect(screen.getByText('PUBLISHED')).toBeInTheDocument(); // render callback
  });

  it('boşken EmptyState gösterir', () => {
    render(<DataTable columns={columns} rows={[]} emptyTitle="Hiç soundscape yok" />);
    expect(screen.getByRole('status')).toHaveTextContent('Hiç soundscape yok');
  });
});

describe('ConfirmDialog', () => {
  it('open=false iken render etmez', () => {
    render(<ConfirmDialog open={false} title="Sil?" onConfirm={() => {}} onCancel={() => {}} />);
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
  });

  it('onConfirm/onCancel çağrılır', async () => {
    const onConfirm = vi.fn();
    const onCancel = vi.fn();
    const user = userEvent.setup();
    render(
      <ConfirmDialog
        open
        title="Yayından kaldır?"
        danger
        onConfirm={onConfirm}
        onCancel={onCancel}
      />,
    );
    expect(screen.getByRole('dialog')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: /vazgeç/i }));
    expect(onCancel).toHaveBeenCalledTimes(1);
    await user.click(screen.getByRole('button', { name: /onayla/i }));
    expect(onConfirm).toHaveBeenCalledTimes(1);
  });
});
