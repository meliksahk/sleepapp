import { ARCHETYPE_MATRIX_V1, type QuestionMatrix } from '../domain/archetype';

/** Geçerli soru matrisini döner (istemci testi render eder). */
export class GetQuestionsUseCase {
  execute(): QuestionMatrix {
    return ARCHETYPE_MATRIX_V1;
  }
}
