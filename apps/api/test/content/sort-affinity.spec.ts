import { sortByAffinity, type Soundscape } from '../../src/modules/content/domain/soundscape';

const s = (slug: string, affinity: string[]): Soundscape => ({
  id: slug,
  slug,
  titleI18n: {},
  engineParams: {},
  layerDefs: {},
  archetypeAffinity: affinity,
  version: 1,
});

describe('sortByAffinity (saf domain)', () => {
  const list = [
    s('a', ['deep-ocean']),
    s('b', ['overthinker']),
    s('c', []),
    s('d', ['overthinker']),
  ];

  it('archetype yoksa sıra değişmez', () => {
    expect(sortByAffinity(list, undefined).map((x) => x.slug)).toEqual(['a', 'b', 'c', 'd']);
  });

  it('eşleşen affinity önce, gerisi sırayı korur', () => {
    expect(sortByAffinity(list, 'overthinker').map((x) => x.slug)).toEqual(['b', 'd', 'a', 'c']);
  });

  it('orijinal listeyi mutasyona uğratmaz', () => {
    const copy = [...list];
    sortByAffinity(list, 'overthinker');
    expect(list.map((x) => x.slug)).toEqual(copy.map((x) => x.slug));
  });
});
