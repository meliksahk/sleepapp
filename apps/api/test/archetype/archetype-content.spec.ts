import {
  ARCHETYPE_INFO,
  getArchetypeInfo,
  hasAllArchetypeInfo,
} from '../../src/modules/archetype/domain/archetype-content';
import { ARCHETYPES } from '../../src/modules/archetype/domain/archetype';

describe('archetype content (saf domain)', () => {
  it("tüm slug'ların içeriği tanımlı", () => {
    expect(hasAllArchetypeInfo()).toBe(true);
    expect(ARCHETYPE_INFO).toHaveLength(ARCHETYPES.length);
  });

  it('getArchetypeInfo: bilinen slug → info, bilinmeyen → undefined', () => {
    expect(getArchetypeInfo('deep-ocean')?.name).toBe('Deep Ocean');
    expect(getArchetypeInfo('yok')).toBeUndefined();
  });

  it('SAĞLIK İDDİASI YOK — yasak kelimeler içerikte geçmez', () => {
    const blob = JSON.stringify(ARCHETYPE_INFO).toLowerCase();
    for (const banned of ['cure', 'treat', 'therapy', 'clinically', 'medical', 'disease']) {
      expect(blob).not.toContain(banned);
    }
  });
});
