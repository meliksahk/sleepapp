import type { AdminUserSummary, UserRepository } from '../domain/ports';

/**
 * Admin kullanıcı araması (docs/02 §165 destek senaryosu). E-posta veya tam id ile
 * kullanıcı bulur. **Yalnızca admin** (endpoint RolesGuard'lı) kullanır.
 *
 * **≥2 karakter zorunlu:** boş/tek harfli sorgu tüm kullanıcı tabanını dökerdi —
 * hem gereksiz veri ifşası hem DoS. Kısa sorgu boş liste döner.
 */
export class SearchUsersUseCase {
  static readonly maxLimit = 50;
  static readonly minQueryLength = 2;

  constructor(private readonly users: UserRepository) {}

  execute(query: string, limit = 20): Promise<AdminUserSummary[]> {
    const trimmed = query.trim();
    if (trimmed.length < SearchUsersUseCase.minQueryLength) return Promise.resolve([]);
    const capped = Math.min(Math.max(limit, 1), SearchUsersUseCase.maxLimit);
    return this.users.searchUsers(trimmed, capped);
  }
}
