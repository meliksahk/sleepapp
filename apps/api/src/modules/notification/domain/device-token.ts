import type { PushTarget } from './push-sender';

/** device_tokens erişimi — push token kaydı + fan-out sorgusu (docs/02 §3). */
export interface DeviceTokenRepository {
  /** İdempotent kayıt: token varsa (cihaz hesap değiştirdi) yeni kullanıcıya atanır. */
  register(userId: string, token: string, platform: string): Promise<void>;
  /** Kullanıcının tüm cihaz hedefleri (fan-out için). userId ile kapsamlanır. */
  findTokensByUser(userId: string): Promise<PushTarget[]>;
  /**
   * Kampanya segmenti (#183): push token'ı OLAN farklı kullanıcı id'leri. Push'u yalnızca
   * kayıtlı cihazı olanlar alabilir, dolayısıyla doğal hedef kümesi budur. [platform]
   * verilirse yalnızca o platformun cihazları (ör. yalnızca ios kampanyası).
   */
  findUserIdsWithTokens(platform?: string): Promise<string[]>;
}

export const DEVICE_TOKEN_REPOSITORY = Symbol('DeviceTokenRepository');
