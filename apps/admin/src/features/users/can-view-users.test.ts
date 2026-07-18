import { describe, it, expect } from 'vitest';
import { canViewUsers } from './can-view-users';

describe('canViewUsers', () => {
  it('owner ve support kullanıcı arar', () => {
    expect(canViewUsers(['owner'])).toBe(true);
    expect(canViewUsers(['support'])).toBe(true);
  });

  it('ÇEKİRDEK: editor ve analyst GÖREMEZ (e-posta PII — API ile aynı daraltma)', () => {
    expect(canViewUsers(['editor'])).toBe(false);
    expect(canViewUsers(['analyst'])).toBe(false);
  });

  it('rol yoksa göremez', () => {
    expect(canViewUsers([])).toBe(false);
  });

  it('rollerden HERHANGİ biri yeterli', () => {
    expect(canViewUsers(['analyst', 'support'])).toBe(true);
  });
});
