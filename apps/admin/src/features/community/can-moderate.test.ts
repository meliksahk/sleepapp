import { describe, it, expect } from 'vitest';
import { canModerateCommunity } from './types';

describe('canModerateCommunity (bölüm görünürlüğü — gerçek kapı API @Roles)', () => {
  it('owner ve editor görebilir', () => {
    expect(canModerateCommunity(['owner'])).toBe(true);
    expect(canModerateCommunity(['editor'])).toBe(true);
  });

  it.each<[string[]]>([[['analyst']], [['support']], [[]]])('%s göremez', (roles) => {
    expect(canModerateCommunity(roles)).toBe(false);
  });
});
