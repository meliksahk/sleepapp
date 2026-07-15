import {
  ARCHETYPE_MATRIX_V1,
  findInvalidAnswer,
  scoreAnswers,
  type Answers,
} from '../domain/archetype';
import { InvalidAnswersError, UnsupportedMatrixVersionError } from '../domain/errors';
import type { ArchetypeResult, ArchetypeResultRepository } from '../domain/ports';

/** Cevapları skorlar, sonucu kalıcılaştırır (docs/04 M1 — web ile aynı matris). */
export class SubmitAnswersUseCase {
  constructor(private readonly results: ArchetypeResultRepository) {}

  async execute(userId: string, version: number, answers: Answers): Promise<ArchetypeResult> {
    if (version !== ARCHETYPE_MATRIX_V1.version) {
      throw new UnsupportedMatrixVersionError(version, ARCHETYPE_MATRIX_V1.version);
    }
    const invalid = findInvalidAnswer(ARCHETYPE_MATRIX_V1, answers);
    if (invalid) {
      throw new InvalidAnswersError(invalid);
    }
    const { archetypeSlug, scores } = scoreAnswers(ARCHETYPE_MATRIX_V1, answers);
    return this.results.save(userId, {
      archetypeSlug,
      answers,
      scores,
      version: ARCHETYPE_MATRIX_V1.version,
    });
  }
}
