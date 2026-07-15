import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { Button } from './button';

describe('Button', () => {
  it('içeriği gösterir ve tıklamayı iletir', async () => {
    const onClick = vi.fn();
    const user = userEvent.setup();
    render(<Button onClick={onClick}>Kaydet</Button>);
    await user.click(screen.getByRole('button', { name: 'Kaydet' }));
    expect(onClick).toHaveBeenCalledTimes(1);
  });

  it('disabled iken tıklanamaz', async () => {
    const onClick = vi.fn();
    const user = userEvent.setup();
    render(
      <Button onClick={onClick} disabled>
        Kaydet
      </Button>,
    );
    await user.click(screen.getByRole('button', { name: 'Kaydet' }));
    expect(onClick).not.toHaveBeenCalled();
  });

  it('variant sınıfını uygular', () => {
    render(<Button variant="danger">Sil</Button>);
    expect(screen.getByRole('button', { name: 'Sil' }).className).toContain('bg-danger');
  });
});
