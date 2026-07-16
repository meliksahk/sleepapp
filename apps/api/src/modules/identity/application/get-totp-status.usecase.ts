import type { UserRepository } from '../domain/ports';

export interface TotpStatus {
  /** 2FA gerçekten etkin mi (onaylanmış mı) — anahtarın VARLIĞI yetmez. */
  readonly enabled: boolean;
  /** Anahtar üretilmiş ama onaylanmamış: kullanıcı kurulumu yarıda bırakmış. */
  readonly pending: boolean;
}

/**
 * Panelin "2FA durumu" rozeti (docs/03 A0).
 *
 * NEDEN `/v1/auth/me`'ye EKLENMEDİ: `me` yalnızca token claim'lerinden okur, DB'ye
 * hiç gitmez ve mobil uygulama onu sık çağırır. Oraya bir DB sorgusu eklemek, 2FA
 * ekranı yılda birkaç kez açılırken sıcak yolu her istekte yavaşlatırdı.
 *
 * `enabled` ile `pending` AYRI: ikisini tek bayrağa indirmek, yarıda kalmış kurulumu
 * ya "etkin" (yalan — kullanıcı kod üretemiyor) ya da "hiç başlamamış" (kafa
 * karıştırıcı — ekran neden baştan başlatıyor?) gösterirdi.
 */
export class GetTotpStatusUseCase {
  constructor(private readonly users: UserRepository) {}

  async execute(userId: string): Promise<TotpStatus> {
    const found = await this.users.findAdminCredentialsById(userId);
    if (found === null) {
      // Admin olmayan hesapta 2FA kavramı yok; hata yerine "kapalı" demek yeterli
      // ve uç zaten admin token'ı ister.
      return { enabled: false, pending: false };
    }
    return {
      enabled: found.totpConfirmedAt !== null,
      pending: found.totpConfirmedAt === null && found.totpSecret !== null,
    };
  }
}
