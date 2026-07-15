import {
  ARCHETYPE_MATRIX_V1,
  findInvalidAnswer,
  scoreAnswers,
  type Answers,
} from '../domain/archetype';
import { InvalidAnswersError, UnsupportedMatrixVersionError } from '../domain/errors';
import type {
  SlugGenerator,
  WebArchetypeResult,
  WebArchetypeResultRepository,
} from '../domain/web';

/**
 * Anonim web skorlaması (docs/05 W0). Kimlik gerektirmez; sonucu paylaşım slug'ı
 * ile kaydeder → /a/{...} sayfası + OG. IP rate-limit presentation'da (throttler).
 */
export class ScoreWebUseCase {
  constructor(
    private readonly results: WebArchetypeResultRepository,
    private readonly slugs: SlugGenerator,
  ) {}

  async execute(version: number, answers: Answers): Promise<WebArchetypeResult> {
    if (version !== ARCHETYPE_MATRIX_V1.version) {
      throw new UnsupportedMatrixVersionError(version, ARCHETYPE_MATRIX_V1.version);
    }
    const invalid = findInvalidAnswer(ARCHETYPE_MATRIX_V1, answers);
    if (invalid) {
      throw new InvalidAnswersError(invalid);
    }
    const { archetypeSlug, scores } = scoreAnswers(ARCHETYPE_MATRIX_V1, answers);
    return this.results.save({
      shareSlug: this.slugs.generate(),
      archetypeSlug,
      scores,
      version: ARCHETYPE_MATRIX_V1.version,
    });
  }
}
