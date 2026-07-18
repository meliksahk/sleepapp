import { DEFAULT_LOCALE, type Locale } from '../../../shared/locale';
import { ARCHETYPE_MATRIX_V1, type QuestionMatrix } from '../domain/archetype';
import { localizeMatrix } from '../domain/archetype-i18n';

/**
 * Geçerli soru matrisini istenen dilde döner (istemci testi render eder).
 *
 * **Skorlama bu çıktıya bağlı DEĞİLDİR:** cevaplar id ile gönderilir ve
 * `SubmitAnswersUseCase` kanonik (çevrilmemiş) matrise karşı skorlar. Yani dil
 * değişse de sonuç aynıdır — çeviri hatası skoru bozamaz.
 */
export class GetQuestionsUseCase {
  execute(locale: Locale = DEFAULT_LOCALE): QuestionMatrix {
    return localizeMatrix(ARCHETYPE_MATRIX_V1, locale);
  }
}
