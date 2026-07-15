import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { StatCard } from './stat-card';
import { EmptyState } from './empty-state';
import { Button } from './button';

describe('StatCard', () => {
  it('label, value ve hint gösterir', () => {
    render(<StatCard label="D7 retention" value="42%" hint="+3 pt" />);
    expect(screen.getByText('D7 retention')).toBeInTheDocument();
    expect(screen.getByText('42%')).toBeInTheDocument();
    expect(screen.getByText('+3 pt')).toBeInTheDocument();
  });
});

describe('EmptyState', () => {
  it('başlık/açıklama/aksiyon gösterir (role=status)', () => {
    render(
      <EmptyState
        title="Henüz içerik yok"
        description="İlk soundscape'i oluştur."
        action={<Button>Oluştur</Button>}
      />,
    );
    const region = screen.getByRole('status');
    expect(region).toHaveTextContent('Henüz içerik yok');
    expect(region).toHaveTextContent("İlk soundscape'i oluştur.");
    expect(screen.getByRole('button', { name: 'Oluştur' })).toBeInTheDocument();
  });
});
