import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { SiteFooter } from './SiteFooter';

describe('SiteFooter', () => {
  it('temel iç bağlantıları doğru href ile render eder', () => {
    render(<SiteFooter />);
    const identities = screen.getByRole('link', { name: 'Sleep identities' });
    const test = screen.getByRole('link', { name: 'Take the test' });
    const faq = screen.getByRole('link', { name: 'FAQ' });
    expect(identities).toHaveAttribute('href', '/archetypes');
    expect(test).toHaveAttribute('href', '/test');
    expect(faq).toHaveAttribute('href', '/faq');
  });

  it('erişilebilir footer navigasyonu (aria-label)', () => {
    render(<SiteFooter />);
    expect(screen.getByRole('navigation', { name: 'Footer' })).toBeInTheDocument();
  });

  it('sağlık iddiası yok — konumlandırma metni', () => {
    render(<SiteFooter />);
    const text = document.body.textContent?.toLowerCase() ?? '';
    for (const banned of ['cure', 'treat', 'therapy', 'clinically', 'medical', 'disease']) {
      expect(text).not.toContain(banned);
    }
  });
});
