/** device_tokens erişimi — push token kaydı (docs/02 §3). */
export interface DeviceTokenRepository {
  /** İdempotent kayıt: token varsa (cihaz hesap değiştirdi) yeni kullanıcıya atanır. */
  register(userId: string, token: string, platform: string): Promise<void>;
}

export const DEVICE_TOKEN_REPOSITORY = Symbol('DeviceTokenRepository');
