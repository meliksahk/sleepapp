/**
 * Push teslim kuyruğu portu (docs/02 B3 — güvenilir asenkron teslim).
 *
 * Kampanya fan-out'u (owner → segment) HTTP isteği içinde SENKRON yapılamaz: binlerce
 * kullanıcıda istek zaman aşımına uğrar. Bu port, teslimi istekten AYIRIR — owner anında
 * "kuyruğa alındı" yanıtı alır, teslim arka planda (worker) olur.
 *
 * İki adaptör (cache modülüyle aynı REDIS_URL-gate deseni):
 *  - `BullMqPushQueue`  (REDIS_URL varsa): Redis'e yazar, worker sonra işler + yeniden dener.
 *  - `InlinePushQueue`  (yoksa): hemen işler — dev/test için, Redis'siz tam çalışır.
 */
export const PUSH_QUEUE = Symbol('PUSH_QUEUE');

/** Tek bir alıcıya teslim işi. Kuyrukta serileşir (yalnız ilkel alanlar). */
export interface CampaignJob {
  readonly userId: string;
  readonly title: string;
  readonly body: string;
}

export interface PushQueue {
  /**
   * Bir teslim işini kuyruğa alır. Gerçek adaptörde Redis'e yazılır (worker sonra işler);
   * inline adaptörde çağrı dönmeden önce işlenir. Her iki durumda da HATA FIRLATABİLİR
   * (enqueue başarısızsa kampanya use case'i bunu görür — sessizce yutulmaz).
   */
  enqueue(job: CampaignJob): Promise<void>;
}
