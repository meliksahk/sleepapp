import type { UserRepository } from '../domain/ports';

/**
 * Hesap silme (App Store zorunluluğu, docs/02 §6 KVKK/GDPR). Kullanıcı satırının
 * silinmesi FK ON DELETE CASCADE ile tüm ilişkili veriyi temizler. MinIO nesne
 * temizliği (share-cards vb.) kullanıcı üretimi nesneler eklendiğinde buraya girer.
 */
export class DeleteAccountUseCase {
  constructor(private readonly users: UserRepository) {}

  async execute(userId: string): Promise<void> {
    await this.users.deleteById(userId);
  }
}
