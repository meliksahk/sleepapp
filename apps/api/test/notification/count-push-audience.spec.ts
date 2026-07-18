import { CountPushAudienceUseCase } from '../../src/modules/notification/application/count-push-audience.usecase';
import type { DeviceTokenRepository } from '../../src/modules/notification/domain/device-token';
import type { PushTarget } from '../../src/modules/notification/domain/push-sender';

const repoWith = (userIds: string[]): DeviceTokenRepository => ({
  register: async () => {},
  findTokensByUser: async (): Promise<PushTarget[]> => [],
  findUserIdsWithTokens: async () => userIds,
});

describe('CountPushAudienceUseCase (#185)', () => {
  it('benzersiz push kullanıcısı sayısını döner', async () => {
    const uc = new CountPushAudienceUseCase(repoWith(['u1', 'u2', 'u3']));
    expect(await uc.execute()).toBe(3);
  });

  it('kimse token kaydetmediyse 0 (dürüst sıfır, uydurma değil)', async () => {
    const uc = new CountPushAudienceUseCase(repoWith([]));
    expect(await uc.execute()).toBe(0);
  });
});
