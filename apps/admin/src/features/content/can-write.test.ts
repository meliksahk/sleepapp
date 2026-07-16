import { describe, it, expect } from 'vitest';
import { canWriteContent } from './can-write';

describe('canWriteContent', () => {
  it('owner ve editor yazar', () => {
    expect(canWriteContent(['owner'])).toBe(true);
    expect(canWriteContent(['editor'])).toBe(true);
  });

  it('analyst ve support yazamaz (salt okunur roller)', () => {
    expect(canWriteContent(['analyst'])).toBe(false);
    expect(canWriteContent(['support'])).toBe(false);
  });

  it('rol yoksa yazamaz', () => {
    expect(canWriteContent([])).toBe(false);
  });

  it('rollerden HERHANGİ biri yeterli', () => {
    expect(canWriteContent(['analyst', 'editor'])).toBe(true);
  });

  it('tanınmayan rol yetki VERMEZ', () => {
    expect(canWriteContent(['superuser'])).toBe(false);
  });
});
