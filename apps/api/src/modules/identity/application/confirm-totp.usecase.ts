import { InvalidTotpError, TotpAlreadyEnabledError } from '../domain/errors';
import type { Clock, UserRepository } from '../domain/ports';
import { verifyTotp } from '../domain/totp';

/**
 * 2FA kurulumu 2. adım: ilk geçerli kodla etkinleştir (docs/03 A0).
 *
 * NEDEN KOD İSTİYORUZ: onay kodsuz olsaydı, anahtarı Authenticator'a YANLIŞ giren
 * (ya da hiç girmeyen) kullanıcı 2FA'yı açmış olur ve bir daha ASLA giremezdi.
 * Geçerli kod, "üretebiliyorum" kanıtıdır — kilitlenmeye karşı tek gerçek güvence.
 */
export class ConfirmTotpUseCase {
  constructor(
    private readonly users: UserRepository,
    private readonly clock: Clock,
  ) {}

  async execute(userId: string, code: string): Promise<void> {
    const current = await this.users.findAdminCredentialsById(userId);

    if (current?.totpConfirmedAt != null) {
      throw new TotpAlreadyEnabledError();
    }
    // Anahtar yoksa kurulum hiç başlamamış demektir.
    if (!current?.totpSecret) {
      throw new InvalidTotpError();
    }

    const used = verifyTotp(current.totpSecret, code, this.clock.now().getTime());
    if (used === null) {
      throw new InvalidTotpError();
    }

    // Sayaç onayla BİRLİKTE yazılır: onay kodu, girişte bir kez daha kullanılamaz.
    await this.users.confirmTotp(userId, this.clock.now(), used);
  }
}
