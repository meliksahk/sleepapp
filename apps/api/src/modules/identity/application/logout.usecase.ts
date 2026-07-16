import type { Clock, RefreshTokenRepository, TokenHasher } from '../domain/ports';

/**
 * Çıkış: refresh token'ın AİLESİNİ düşürür (docs/02 §2.1).
 *
 * NEDEN AİLE, NEDEN TEK TOKEN DEĞİL: rotasyon zinciri boyunca aynı oturumun
 * ardışık token'ları tek `familyId` altında yaşar. Yalnızca elimizdeki token'ı
 * iptal etmek, o oturumdan türemiş başka bir halkayı ayakta bırakabilirdi —
 * "çıkış yaptım" diyen kullanıcı için bu sessiz bir yalan olurdu.
 *
 * IDEMPOTENT ve SESSİZ: bilinmeyen/çoktan iptal edilmiş token için de hatasız
 * döner. Aksi halde yanıt, "bu token gerçek miydi?" sorusunu yanıtlayan bir
 * kâhin (oracle) hâline gelirdi. Çıkışın zaten yapılacak tek şeyi vardır.
 */
export class LogoutUseCase {
  constructor(
    private readonly refreshTokens: RefreshTokenRepository,
    private readonly hasher: TokenHasher,
    private readonly clock: Clock,
  ) {}

  async execute(rawRefreshToken: string): Promise<void> {
    const record = await this.refreshTokens.findByHash(this.hasher.hash(rawRefreshToken));
    if (!record) return;
    await this.refreshTokens.revokeFamily(record.familyId, this.clock.now());
  }
}
