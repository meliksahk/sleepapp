/** Denetim eylemlerinin okunur karşılığı. */
const ACTION_LABELS: Record<string, string> = {
  'soundscape.create': 'oluşturdu',
  'soundscape.update': 'güncelledi',
  'soundscape.publish': 'yayınladı',
  'soundscape.unpublish': 'yayından kaldırdı',
  'soundscape.recipe': 'ses tarifini değiştirdi',
};

/**
 * API yeni bir eylem eklerse panel BOŞ hücre değil ham değeri gösterir: denetim
 * izinde "burada bir şey oldu ama tanımıyorum" görmek, hiçbir şey görmemekten iyidir.
 * (statusLabel'daki aynı ilke.)
 */
export function auditActionLabel(action: string): string {
  return ACTION_LABELS[action] ?? action;
}
