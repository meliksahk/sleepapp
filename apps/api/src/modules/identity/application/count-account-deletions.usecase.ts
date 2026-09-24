import type { AccountDeletionLog } from '../domain/account-deletion-log';

/**
 * Son [days] gün içinde silinen hesap sayısı — identity'nin PUBLIC servisi.
 * Panel panosu bunu tüketir (admin modülü identity'nin repo'suna dokunmaz).
 */
export class CountAccountDeletionsUseCase {
  constructor(private readonly log: AccountDeletionLog) {}

  async execute(days = 30): Promise<number> {
    const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
    return this.log.countSince(since);
  }
}
