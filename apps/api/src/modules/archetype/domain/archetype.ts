/**
 * Sleep archetype domain — saf, test edilebilir skorlama (viral kanca #1, docs/04 M1).
 * Soru matrisi F1'de versiyonlu bir domain sabiti; admin CMS (A1) ile DB'ye taşınacak.
 * Web ve mobil AYNI matrisi kullanır (kontrat eşitliği).
 */
export const ARCHETYPES = ['deep-ocean', 'overthinker', 'delta-drifter', 'dawn-chaser'] as const;
export type ArchetypeSlug = (typeof ARCHETYPES)[number];

export interface QuestionOption {
  readonly id: string;
  readonly label: string;
  readonly archetype: ArchetypeSlug;
}
export interface Question {
  readonly id: string;
  readonly prompt: string;
  readonly options: readonly QuestionOption[];
}
export interface QuestionMatrix {
  readonly version: number;
  readonly questions: readonly Question[];
}

/** questionId → optionId */
export type Answers = Readonly<Record<string, string>>;
export type Scores = Record<ArchetypeSlug, number>;

export interface ScoreResult {
  readonly archetypeSlug: ArchetypeSlug;
  readonly scores: Scores;
}

const opt = (id: string, label: string, archetype: ArchetypeSlug): QuestionOption => ({
  id,
  label,
  archetype,
});

export const ARCHETYPE_MATRIX_V1: QuestionMatrix = {
  version: 1,
  questions: [
    {
      id: 'q1',
      prompt: 'When your head hits the pillow, your mind…',
      options: [
        opt('q1a', 'sinks into stillness', 'deep-ocean'),
        opt('q1b', 'replays the whole day', 'overthinker'),
        opt('q1c', 'drifts somewhere far away', 'delta-drifter'),
        opt('q1d', 'is already planning tomorrow', 'dawn-chaser'),
      ],
    },
    {
      id: 'q2',
      prompt: 'Your ideal bedroom sound is…',
      options: [
        opt('q2a', 'deep ocean hush', 'deep-ocean'),
        opt('q2b', 'soft rain to quiet my thoughts', 'overthinker'),
        opt('q2c', 'slow ambient waves', 'delta-drifter'),
        opt('q2d', 'nothing — I wake with the sun', 'dawn-chaser'),
      ],
    },
    {
      id: 'q3',
      prompt: 'You wake at 3am. You…',
      options: [
        opt('q3a', 'roll over, gone again', 'deep-ocean'),
        opt('q3b', 'start a mental to-do list', 'overthinker'),
        opt('q3c', 'float in a half-dream', 'delta-drifter'),
        opt('q3d', 'check if it is nearly morning', 'dawn-chaser'),
      ],
    },
    {
      id: 'q4',
      prompt: 'Mornings feel best when…',
      options: [
        opt('q4a', 'I slept like a stone', 'deep-ocean'),
        opt('q4b', 'my head finally went quiet', 'overthinker'),
        opt('q4c', 'I remember a vivid dream', 'delta-drifter'),
        opt('q4d', 'the first light wakes me gently', 'dawn-chaser'),
      ],
    },
    {
      id: 'q5',
      prompt: 'Your relationship with your alarm is…',
      options: [
        opt('q5a', 'I rarely need it', 'deep-ocean'),
        opt('q5b', 'I beat it, lying awake', 'overthinker'),
        opt('q5c', 'it pulls me from deep sleep', 'delta-drifter'),
        opt('q5d', 'I am up before it rings', 'dawn-chaser'),
      ],
    },
    {
      id: 'q6',
      prompt: 'A perfect night is…',
      options: [
        opt('q6a', 'deep and dreamless', 'deep-ocean'),
        opt('q6b', 'finally switching off', 'overthinker'),
        opt('q6c', 'long, drifting, surreal', 'delta-drifter'),
        opt('q6d', 'early to bed, early to rise', 'dawn-chaser'),
      ],
    },
  ],
};

const emptyScores = (): Scores => ({
  'deep-ocean': 0,
  overthinker: 0,
  'delta-drifter': 0,
  'dawn-chaser': 0,
});

/** Cevapların matrise göre eksiksiz ve geçerli olduğunu doğrular. */
export function findInvalidAnswer(matrix: QuestionMatrix, answers: Answers): string | null {
  for (const q of matrix.questions) {
    const chosen = answers[q.id];
    if (chosen === undefined) return `missing:${q.id}`;
    if (!q.options.some((o) => o.id === chosen)) return `invalid:${q.id}`;
  }
  return null;
}

/** Skorlar → kazanan archetype (deterministik: eşitlikte ARCHETYPES sırası). */
export function scoreAnswers(matrix: QuestionMatrix, answers: Answers): ScoreResult {
  const scores = emptyScores();
  for (const q of matrix.questions) {
    const chosen = answers[q.id];
    const option = q.options.find((o) => o.id === chosen);
    if (option) scores[option.archetype] += 1;
  }
  let winner: ArchetypeSlug = ARCHETYPES[0];
  for (const slug of ARCHETYPES) {
    if (scores[slug] > scores[winner]) winner = slug;
  }
  return { archetypeSlug: winner, scores };
}
