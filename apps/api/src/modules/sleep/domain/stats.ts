/** Uyku istatistikleri özeti — kullanıcının TÜM kayıtları üzerinden. Saf domain. */
export interface SleepStats {
  /** Kayıtlı benzersiz gece sayısı. */
  readonly nights: number;
  readonly totalDurationMinutes: number;
  /** Oturum başına ortalama süre (gece başına DEĞİL). */
  readonly averageDurationMinutes: number;
}

/**
 * Depodan gelen ham toplam — DB tarafında hesaplanır (SQL agregasyonu), böylece
 * istatistik bir "son N oturum" penceresine hapsolmaz.
 *
 * NEDEN: eskiden son 100 oturum çekilip bellekte özetleniyordu. 100'den fazla
 * oturumu olan kullanıcıda `nights` ve ortalama **SESSİZCE kısmi** veriyi
 * yansıtıyordu — üstelik uygulama bunu genel istatistik gibi gösteriyor
 * ("N nights · avg ..."). Pencere kaldırıldı.
 */
export interface SleepAggregate {
  readonly nights: number;
  readonly sessionCount: number;
  readonly totalDurationMinutes: number;
}

/** Ham toplamı sunulabilir istatistiğe çevirir. Kayıt yoksa hepsi 0. */
export function statsFromAggregate(agg: SleepAggregate): SleepStats {
  if (agg.sessionCount === 0) {
    return { nights: 0, totalDurationMinutes: 0, averageDurationMinutes: 0 };
  }
  return {
    nights: agg.nights,
    totalDurationMinutes: agg.totalDurationMinutes,
    averageDurationMinutes: Math.round(agg.totalDurationMinutes / agg.sessionCount),
  };
}
