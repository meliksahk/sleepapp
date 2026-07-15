import type { DeviceRegistration, IssuedSession, User } from '../domain/user.entity';
import type { Clock, IdGenerator, UserRepository } from '../domain/ports';
import type { SessionMinter } from './session-minter';

/**
 * Anonim cihaz kaydı (POST /v1/auth/device). Onboarding'i sürtünmesiz başlatır:
 * cihaz daha önce kayıtlıysa aynı kullanıcıyı yeniden kullanır (idempotent),
 * değilse yeni anonim kullanıcı + cihaz oluşturur. Her iki halde yeni oturum verir.
 */
export class RegisterDeviceUseCase {
  constructor(
    private readonly users: UserRepository,
    private readonly ids: IdGenerator,
    private readonly clock: Clock,
    private readonly sessions: SessionMinter,
  ) {}

  async execute(input: DeviceRegistration): Promise<IssuedSession> {
    const existing = await this.users.findByDeviceFingerprint(input.fingerprint);
    const user: User =
      existing ??
      (() => {
        const created: User = {
          id: this.ids.uuid(),
          kind: 'anonymous',
          roles: [],
          createdAt: this.clock.now(),
        };
        return created;
      })();

    if (!existing) {
      await this.users.createWithDevice(user, input);
    }

    return this.sessions.mint({
      userId: user.id,
      roles: user.roles,
      familyId: this.ids.uuid(),
    });
  }
}
