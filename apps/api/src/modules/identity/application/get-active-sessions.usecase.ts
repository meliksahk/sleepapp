import type { ActiveSessionInfo } from '../domain/user.entity';
import type { Clock, RefreshTokenRepository } from '../domain/ports';

/** Kullanıcının aktif oturumları (cihaz listesi). Token HİÇ dışa verilmez. */
export class GetActiveSessionsUseCase {
  constructor(
    private readonly refreshTokens: RefreshTokenRepository,
    private readonly clock: Clock,
  ) {}

  execute(userId: string): Promise<ActiveSessionInfo[]> {
    return this.refreshTokens.listActiveByUser(userId, this.clock.now());
  }
}
