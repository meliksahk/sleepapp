import { buildArchetypeShare, slugToDisplayName } from '../../src/modules/sharing/domain/share';

const urls = { webBaseUrl: 'https://nocta.app', appScheme: 'nocta' };

describe('sharing domain (saf)', () => {
  it('slugToDisplayName: kebab → Title Case', () => {
    expect(slugToDisplayName('deep-ocean')).toBe('Deep Ocean');
    expect(slugToDisplayName('overthinker')).toBe('Overthinker');
  });

  it('buildArchetypeShare: web + deep link + başlık', () => {
    const share = buildArchetypeShare('deep-ocean', urls);
    expect(share.archetypeSlug).toBe('deep-ocean');
    expect(share.title).toBe('My sleep identity is Deep Ocean');
    expect(share.webUrl).toBe('https://nocta.app/a/deep-ocean');
    expect(share.deepLink).toBe('nocta://a/deep-ocean');
  });

  it('web base URL sonundaki slash temizlenir (çift slash yok)', () => {
    const share = buildArchetypeShare('overthinker', { ...urls, webBaseUrl: 'https://nocta.app/' });
    expect(share.webUrl).toBe('https://nocta.app/a/overthinker');
  });

  it('SAĞLIK İDDİASI YOK — yasak kelimeler paylaşım metninde geçmez', () => {
    const blob = JSON.stringify(buildArchetypeShare('delta-drifter', urls)).toLowerCase();
    for (const banned of ['cure', 'treat', 'therapy', 'clinically', 'medical', 'disease']) {
      expect(blob).not.toContain(banned);
    }
  });
});
