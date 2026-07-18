import { describe, it, expect } from 'vitest';
import { canEditFlags } from './can-edit-flags';

describe('canEditFlags', () => {
  it('owner düzenleyebilir', () => {
    expect(canEditFlags(['owner'])).toBe(true);
  });

  it('editor DÜZENLEYEMEZ (içerik editörü ≠ flag sahibi)', () => {
    // Flag'ler her özelliğin rollout'unu kontrol eder → owner-özel (API #167 ile aynı).
    expect(canEditFlags(['editor'])).toBe(false);
  });

  it('analyst ve support düzenleyemez', () => {
    expect(canEditFlags(['analyst'])).toBe(false);
    expect(canEditFlags(['support'])).toBe(false);
  });

  it('rol yoksa düzenleyemez', () => {
    expect(canEditFlags([])).toBe(false);
  });
});
