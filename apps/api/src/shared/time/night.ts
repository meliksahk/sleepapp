/**
 * "Gece" tanımı — TEK paylaşılan fonksiyon (CLAUDE.md §4). Uyku oturumları
 * kullanıcının YEREL gününe göre gruplanır; sınır sabah 06:00'dır.
 *
 * Kural: yerel saat < 06:00 ise oturum bir ÖNCEKİ takvim gününün gecesine aittir
 * (akşam başlayıp sabaha sarkan uyku aynı geceye sayılır). 06:00 ve sonrası o günün.
 * Örn. 23:00 10 Oca ve 02:00 11 Oca → ikisi de "10 Oca gecesi".
 *
 * Dönüş: gece etiketi `YYYY-MM-DD` (yerel takvim tarihi). DST-güvenli: yalnızca
 * takvim tarihi üzerinde aritmetik yapılır, duvar-saati kaydırılmaz.
 */
export const NIGHT_BOUNDARY_HOUR = 6;

export function nightDateOf(instant: Date, timezone: string): string {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(instant);

  const get = (type: Intl.DateTimeFormatPartTypes): number => {
    const part = parts.find((p) => p.type === type);
    if (!part) throw new Error(`Beklenen tarih parçası yok: ${type}`);
    return Number.parseInt(part.value, 10);
  };

  const year = get('year');
  const month = get('month');
  const day = get('day');
  const hour = get('hour');

  // Takvim tarihini UTC epoch olarak tut (duvar-saati yok) → gün çıkarma DST-güvenli.
  const cal = new Date(Date.UTC(year, month - 1, day));
  if (hour < NIGHT_BOUNDARY_HOUR) {
    cal.setUTCDate(cal.getUTCDate() - 1);
  }

  const y = cal.getUTCFullYear().toString().padStart(4, '0');
  const m = (cal.getUTCMonth() + 1).toString().padStart(2, '0');
  const d = cal.getUTCDate().toString().padStart(2, '0');
  return `${y}-${m}-${d}`;
}
