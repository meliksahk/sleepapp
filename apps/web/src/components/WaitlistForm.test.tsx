import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { WaitlistForm } from './WaitlistForm';

const okResponse = () => ({ ok: true, status: 202, json: async () => ({}) }) as Response;

describe('WaitlistForm', () => {
  beforeEach(() =>
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => okResponse()),
    ),
  );
  afterEach(() => vi.unstubAllGlobals());

  it('e-posta gönderir ve başarı mesajı gösterir', async () => {
    const user = userEvent.setup();
    render(<WaitlistForm />);

    await user.type(screen.getByLabelText('E-posta'), 'me@example.com');
    await user.click(screen.getByRole('button', { name: /katıl/i }));

    expect(await screen.findByRole('status')).toBeInTheDocument();
    expect(fetch).toHaveBeenCalledWith(
      expect.stringContaining('/v1/waitlist'),
      expect.objectContaining({ method: 'POST' }),
    );
  });

  it('hata durumunda uyarı gösterir', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => ({ ok: false, status: 500, json: async () => ({}) }) as Response),
    );
    const user = userEvent.setup();
    render(<WaitlistForm />);
    await user.type(screen.getByLabelText('E-posta'), 'me@example.com');
    await user.click(screen.getByRole('button', { name: /katıl/i }));
    expect(await screen.findByRole('alert')).toBeInTheDocument();
  });
});
