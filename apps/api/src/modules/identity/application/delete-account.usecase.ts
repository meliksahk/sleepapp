import type { AccountDeletionLog } from '../domain/account-deletion-log';
import type { UserRepository } from '../domain/ports';

/**
 * Hesap silme (App Store zorunluluğu, docs/02 §6 KVKK/GDPR). Kullanıcı satırının
 * silinmesi FK ON DELETE CASCADE ile tüm ilişkili veriyi temizler. MinIO nesne
 * temizliği (share-cards vb.) kullanıcı üretimi nesneler eklendiğinde buraya girer.
 *
 * **Sayaç silmeden SONRA yazılır.** Önce yazsaydık, silme patladığında olmamış bir
 * olayı saymış olurduk — panel "10 hesap silindi" derken 10 hesap duruyor olurdu.
 * Sayaç kimlik TAŞIMAZ (bkz. `AccountDeletionLog`).
 */
export class DeleteAccountUseCase {
  constructor(
    private readonly users: UserRepository,
    private readonly deletions?: AccountDeletionLog,
  ) {}

  async execute(userId: string): Promise<void> {
    await this.users.deleteById(userId);
    await this.deletions?.record();
  }
}
