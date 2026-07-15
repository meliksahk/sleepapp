import { describe, it, expect, vi, afterEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { ShareButton } from './ShareButton';

const props = { title: 'My sleep identity is Deep Ocean', url: 'https://nocta.app/a/deep-ocean' };

afterEach(() => {
  vi.restoreAllMocks();
  // navigator.share'i testler arası temizle.
  Reflect.deleteProperty(navigator, 'share');
});

describe('ShareButton', () => {
  it('Web Share API varsa navigator.share çağrılır (title + url)', async () => {
    const share = vi.fn().mockResolvedValue(undefined);
    Object.defineProperty(navigator, 'share', { value: share, configurable: true });

    render(<ShareButton {...props} />);
    fireEvent.click(screen.getByRole('button'));

    await waitFor(() => expect(share).toHaveBeenCalledWith({ title: props.title, url: props.url }));
    // Paylaşım başarılıysa "Link copied" gösterilmez.
    expect(screen.queryByText('Link copied')).toBeNull();
  });

  it('Web Share yoksa panoya kopyalar ve "Link copied" gösterir', async () => {
    const writeText = vi.fn().mockResolvedValue(undefined);
    Object.defineProperty(navigator, 'clipboard', { value: { writeText }, configurable: true });

    render(<ShareButton {...props} />);
    fireEvent.click(screen.getByRole('button'));

    await waitFor(() => expect(writeText).toHaveBeenCalledWith(props.url));
    expect(await screen.findByText('Link copied')).toBeTruthy();
  });
});
