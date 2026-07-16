import { InvalidCredentialsError, TotpAlreadyEnabledError } from '../domain/errors';
import type { UserRepository } from '../domain/ports';
import { generateTotpSecret, totpAuthUri } from '../domain/totp';

/** Kurulum çıktısı: QR için URI + elle giriş için anahtar. */
export interface TotpEnrollment {
  readonly secret: string;
  readonly otpauthUri: string;
}

/**
 * 2FA kurulumu 1. adım: gizli anahtar üret ve döndür (docs/03 A0).
 *
 * ANAHTARI DÖNDÜRMEK ZORUNLU: kullanıcı onu Authenticator'a girmeli. Bu, gizli
 * anahtarın açık metin olarak ağdan geçtiği TEK an — kaçınılmaz (TOTP'nin doğası).
 * Bu yüzden: yalnızca kimliği doğrulanmış hesap kendi anahtarını alır ve anahtar
 * ASLA loglanmaz.
 *
 * ONAY AYRI ADIM (confirm): burada 2FA zorunlu OLMAZ. Yoksa anahtarı üretip
 * Authenticator'a girmeden kapatan kullanıcı kendini kalıcı kilitlerdi.
 */
export class EnrollTotpUseCase {
  constructor(private readonly users: UserRepository) {}

  async execute(userId: string): Promise<TotpEnrollment> {
    const current = await this.users.findAdminCredentialsById(userId);
    if (current === null) {
      throw new InvalidCredentialsError();
    }

    // Etkin 2FA'nın üstüne yazmak, kodu ele geçirenin 2FA'yı KENDİ cihazına
    // taşımasına izin verirdi — korumayı saldırganın eline verirdi. Sıfırlama,
    // parola doğrulaması isteyen ayrı bir akış olmalı (henüz yok — defterde).
    if (current.totpConfirmedAt !== null) {
      throw new TotpAlreadyEnabledError();
    }

    // Yarıda kalmış kurulumun anahtarının ÜSTÜNE YAZILIR: onaylanmamış anahtarın
    // hiçbir değeri yok ve kullanıcı baştan başlayabilmeli.
    const secret = generateTotpSecret();
    await this.users.setTotpSecret(userId, secret);

    // Etiket repodan gelen e-posta ile: istemcinin verdiği değere güvenilmez.
    return { secret, otpauthUri: totpAuthUri(secret, current.email) };
  }
}
