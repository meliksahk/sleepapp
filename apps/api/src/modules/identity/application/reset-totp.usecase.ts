import { InvalidCredentialsError } from '../domain/errors';
import type { PasswordHasher, UserRepository } from '../domain/ports';

/**
 * 2FA sıfırlama (#186): PAROLA doğrulamasıyla mevcut 2FA'yı kaldırır → kullanıcı yeni
 * cihazda yeniden kurabilir (`EnrollTotp` artık "zaten etkin" demez).
 *
 * `enroll-totp.usecase.ts`'te not düşülen boşluğu kapatır: etkin 2FA'nın üstüne PAROLA
 * OLMADAN yazmak, oturumu ele geçirenin 2FA'yı KENDİ cihazına taşımasına izin verirdi —
 * korumayı saldırganın eline verirdi. Bu yüzden parola ZORUNLU (login ile aynı argon2
 * doğrulaması). Kullanım: kimliği doğrulanmış admin, 2FA cihazını değiştirmek istediğinde.
 */
export class ResetTotpUseCase {
  constructor(
    private readonly users: UserRepository,
    private readonly passwords: PasswordHasher,
  ) {}

  async execute(userId: string, password: string): Promise<void> {
    const creds = await this.users.findAdminCredentialsById(userId);
    if (creds === null) {
      // Admin değil / parolası yok → 2FA'sı da olamaz. Tek mesaj (kullanıcı sayımı yok).
      throw new InvalidCredentialsError();
    }
    const ok = await this.passwords.verify(creds.passwordHash, password);
    if (!ok) {
      throw new InvalidCredentialsError();
    }
    await this.users.clearTotp(userId);
  }
}
