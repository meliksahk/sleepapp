import { translate, type Locale, type MessageKey } from '@/shared/i18n/dictionaries';

/** Denetim eylemlerinin okunur karşılığı. */
const ACTION_KEYS: Record<string, MessageKey> = {
  'soundscape.create': 'audit.soundscapeCreate',
  'soundscape.update': 'audit.soundscapeUpdate',
  'soundscape.publish': 'audit.soundscapePublish',
  'soundscape.unpublish': 'audit.soundscapeUnpublish',
  'soundscape.recipe': 'audit.soundscapeRecipe',
};

/**
 * API yeni bir eylem eklerse panel BOŞ hücre değil ham değeri gösterir: denetim
 * izinde "burada bir şey oldu ama tanımıyorum" görmek, hiçbir şey görmemekten iyidir.
 * (statusLabel'daki aynı ilke.)
 */
export function auditActionLabel(locale: Locale, action: string): string {
  const key = ACTION_KEYS[action];
  return key === undefined ? action : translate(locale, key);
}
