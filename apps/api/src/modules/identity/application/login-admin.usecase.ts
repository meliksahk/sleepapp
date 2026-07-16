import { audienceForKind } from '../domain/user.entity';
import type { IssuedSession } from '../domain/user.entity';
import { InvalidCredentialsError } from '../domain/errors';
import type { IdGenerator, PasswordHasher, UserRepository } from '../domain/ports';
import type { SessionMinter } from './session-minter';

/**
 * Admin panel girişi: e-posta + parola → oturum (docs/03 A0).
 *
 * KULLANICI SAYIMINA (user enumeration) KARŞI: hesap yoksa da parola doğrulaması
 * SAHTE bir hash'e karşı yine koşulur. Aksi halde "hesap yok" yolu ~ölçülebilir
 * biçimde hızlı olurdu ve saldırgan hangi e-postaların admin olduğunu zamanlamadan
 * çıkarabilirdi. Her iki yol da aynı hatayı atar — mesaj da ayırt etmez.
 *
 * Not: bu, zamanlamayı EŞİTLEMEZ, yalnızca "hesap yok" durumunu ucuz olmaktan
 * çıkarır (argon2 maliyeti her iki yolda da ödenir). Tam sabit-zaman iddiası
 * etmiyorum; ağ gürültüsü zaten bu farkı bastırır.
 */
export class LoginAdminUseCase {
  /**
   * Sabit bir argon2id hash'i (parolası "*" olan). Sahte doğrulama için gerçek bir
   * hash gerekir — rastgele string verify()'ı hemen false döndürür (maliyet ödenmez).
   * İlk kullanımda üretilir, süreç boyunca yeniden kullanılır.
   */
  private dummyHash: string | null = null;

  constructor(
    private readonly users: UserRepository,
    private readonly passwords: PasswordHasher,
    private readonly ids: IdGenerator,
    private readonly sessions: SessionMinter,
  ) {}

  async execute(email: string, password: string): Promise<IssuedSession> {
    const found = await this.users.findAdminCredentialsByEmail(email.trim().toLowerCase());

    if (found === null) {
      await this.passwords.verify(await this.getDummyHash(), password);
      throw new InvalidCredentialsError();
    }

    const ok = await this.passwords.verify(found.passwordHash, password);
    if (!ok) {
      throw new InvalidCredentialsError();
    }

    return this.sessions.mint({
      userId: found.userId,
      roles: found.roles,
      familyId: this.ids.uuid(),
      // Repo yalnızca kind='admin' döndürür → audience daima 'admin'.
      aud: audienceForKind('admin'),
    });
  }

  private async getDummyHash(): Promise<string> {
    this.dummyHash ??= await this.passwords.hash('*');
    return this.dummyHash;
  }
}
