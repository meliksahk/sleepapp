import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { ArchetypeTest } from './ArchetypeTest';

const matrix = {
  version: 1,
  questions: [
    {
      id: 'q1',
      prompt: 'Question one?',
      options: [
        { id: 'q1a', label: 'Option A1', archetype: 'deep-ocean' },
        { id: 'q1b', label: 'Option B1', archetype: 'overthinker' },
      ],
    },
    {
      id: 'q2',
      prompt: 'Question two?',
      options: [
        { id: 'q2a', label: 'Option A2', archetype: 'deep-ocean' },
        { id: 'q2b', label: 'Option B2', archetype: 'overthinker' },
      ],
    },
  ],
};

const jsonResponse = (data: unknown, ok = true) =>
  ({ ok, status: ok ? 200 : 400, json: async () => data }) as Response;

describe('ArchetypeTest', () => {
  beforeEach(() => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async (url: string | URL, opts?: RequestInit) => {
        const u = String(url);
        if (u.endsWith('/v1/archetype/web/questions')) return jsonResponse(matrix);
        if (u.endsWith('/v1/archetype/web') && opts?.method === 'POST') {
          return jsonResponse({
            shareSlug: 'abc123',
            archetypeSlug: 'overthinker',
            scores: { overthinker: 2 },
            version: 1,
          });
        }
        return jsonResponse({}, false);
      }),
    );
  });
  afterEach(() => vi.unstubAllGlobals());

  it('soruları yükler, cevapları toplar, gönderir ve sonucu gösterir', async () => {
    const user = userEvent.setup();
    render(<ArchetypeTest />);

    // Sorular yüklenir
    expect(await screen.findByText('Question one?')).toBeInTheDocument();
    expect(screen.getByText('Question two?')).toBeInTheDocument();

    // Tüm sorular cevaplanmadan buton disabled
    const submit = screen.getByRole('button', { name: /sonucu gör/i });
    expect(submit).toBeDisabled();

    await user.click(screen.getByLabelText('Option B1'));
    await user.click(screen.getByLabelText('Option B2'));
    expect(submit).toBeEnabled();

    await user.click(submit);

    // Sonuç görünür
    expect(await screen.findByText(/overthinker/i)).toBeInTheDocument();
    const link = screen.getByRole('link', { name: /archetype/i });
    expect(link).toHaveAttribute('href', '/a/overthinker');

    // VİRAL DÖNGÜ (docs/05): sonuç anında paylaşım kartı + kaydet düğmesi burada olmalı
    // (kullanıcı /a/[slug]'a gitmeden paylaşabilsin — edinim döngüsü kapanır).
    expect(screen.getByRole('button', { name: /save your card/i })).toBeInTheDocument();
    expect(screen.getByLabelText(/share card preview/i)).toBeInTheDocument();
  });

  it('sorular yüklenemezse hata gösterir', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => jsonResponse({}, false)),
    );
    render(<ArchetypeTest />);
    await waitFor(() => expect(screen.getByRole('alert')).toBeInTheDocument());
  });
});
