import type { DeviceTokenRepository } from '../domain/device-token';

/**
 * Erişilebilir push kitlesi (#185): kayıtlı cihazı olan BENZERSİZ kullanıcı sayısı.
 * Owner panosunda "kampanyayla kaç kişiye ulaşırım" sorusunun canlı cevabı — kampanya
 * özelliğinin (#183/#184) doğal metriği. Segment sorgusunu (#183) yeniden kullanır.
 *
 * NOT: opt-out (bildirim kapatma) BURADA düşülmez — kitle "token'ı olan" demektir; fiili
 * gönderim opt-out'u fan-out'ta zaten dışlar (SendNotificationUseCase). Yani bu, erişimin
 * ÜST sınırı; owner bunu bilerek okur.
 */
export class CountPushAudienceUseCase {
  constructor(private readonly tokens: DeviceTokenRepository) {}

  async execute(): Promise<number> {
    return (await this.tokens.findUserIdsWithTokens()).length;
  }
}
