import type { DeviceTokenRepository } from '../domain/device-token';

/** Push cihaz token'ı kaydeder (idempotent). Fan-out worker B3'te + gerçek gönderim docs/10. */
export class RegisterDeviceTokenUseCase {
  constructor(private readonly tokens: DeviceTokenRepository) {}

  execute(userId: string, token: string, platform: string): Promise<void> {
    return this.tokens.register(userId, token, platform);
  }
}
