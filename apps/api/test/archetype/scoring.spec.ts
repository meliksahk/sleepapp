import {
  ARCHETYPE_MATRIX_V1,
  findInvalidAnswer,
  scoreAnswers,
  type Answers,
} from '../../src/modules/archetype/domain/archetype';

const allOf = (letter: string): Answers =>
  Object.fromEntries(ARCHETYPE_MATRIX_V1.questions.map((q) => [q.id, `${q.id}${letter}`]));

describe('archetype scoring (saf domain)', () => {
  it('tüm A cevapları → deep-ocean (6-0-0-0)', () => {
    const r = scoreAnswers(ARCHETYPE_MATRIX_V1, allOf('a'));
    expect(r.archetypeSlug).toBe('deep-ocean');
    expect(r.scores['deep-ocean']).toBe(6);
    expect(r.scores.overthinker).toBe(0);
  });

  it('tüm B cevapları → overthinker', () => {
    expect(scoreAnswers(ARCHETYPE_MATRIX_V1, allOf('b')).archetypeSlug).toBe('overthinker');
  });

  it('tüm D cevapları → dawn-chaser', () => {
    expect(scoreAnswers(ARCHETYPE_MATRIX_V1, allOf('d')).archetypeSlug).toBe('dawn-chaser');
  });

  it('eşitlikte deterministik: ARCHETYPES sırası kazanır (deep-ocean > overthinker)', () => {
    const answers: Answers = {
      q1: 'q1a', // deep-ocean
      q2: 'q2a', // deep-ocean
      q3: 'q3a', // deep-ocean
      q4: 'q4b', // overthinker
      q5: 'q5b', // overthinker
      q6: 'q6b', // overthinker
    };
    const r = scoreAnswers(ARCHETYPE_MATRIX_V1, answers);
    expect(r.scores['deep-ocean']).toBe(3);
    expect(r.scores.overthinker).toBe(3);
    expect(r.archetypeSlug).toBe('deep-ocean'); // eşitlik → sıra
  });

  it('findInvalidAnswer: eksik / geçersiz / tam', () => {
    expect(findInvalidAnswer(ARCHETYPE_MATRIX_V1, { q1: 'q1a' })).toBe('missing:q2');
    expect(findInvalidAnswer(ARCHETYPE_MATRIX_V1, { ...allOf('a'), q3: 'nope' })).toBe(
      'invalid:q3',
    );
    expect(findInvalidAnswer(ARCHETYPE_MATRIX_V1, allOf('a'))).toBeNull();
  });
});
