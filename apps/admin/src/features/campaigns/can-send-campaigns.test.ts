import { describe, it, expect } from 'vitest';
import { canSendCampaigns } from './can-send-campaigns';

describe('canSendCampaigns', () => {
  it('owner gönderebilir', () => {
    expect(canSendCampaigns(['owner'])).toBe(true);
  });

  it('editor GÖNDEREMEZ (kampanya tüm tabana ulaşır → owner-özel)', () => {
    expect(canSendCampaigns(['editor'])).toBe(false);
  });

  it('analyst ve support gönderemez', () => {
    expect(canSendCampaigns(['analyst'])).toBe(false);
    expect(canSendCampaigns(['support'])).toBe(false);
  });

  it('rol yoksa gönderemez', () => {
    expect(canSendCampaigns([])).toBe(false);
  });
});
