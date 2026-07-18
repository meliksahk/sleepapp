import { SendCampaignUseCase } from '../../src/modules/notification/application/send-campaign.usecase';
import { InlinePushQueue } from '../../src/modules/notification/infrastructure/inline-push-queue';
import type { CampaignJob, PushQueue } from '../../src/modules/notification/domain/push-queue';
import type { DeviceTokenRepository } from '../../src/modules/notification/domain/device-token';
import type { SendNotificationUseCase } from '../../src/modules/notification/application/send-notification.usecase';

/**
 * Kampanya use case'i artık teslimi PushQueue'ya DEVREDER (senkron fan-out değil, #190).
 * Bu birim testleri kuyruk MANTIĞINI (her alıcı için tek iş, platform filtresi) Redis'siz
 * doğrular; gerçek Redis üzerinden uçtan uca teslim ayrı entegrasyon testinde.
 */
const repoWith = (userIds: string[], spy?: (platform?: string) => void): DeviceTokenRepository =>
  ({
    findUserIdsWithTokens: async (platform?: string): Promise<string[]> => {
      spy?.(platform);
      return userIds;
    },
  }) as unknown as DeviceTokenRepository;

describe('SendCampaignUseCase (asenkron kuyruk, #190)', () => {
  it('ÇEKİRDEK: her alıcı için tek iş kuyruğa alır, {recipients, queued} döner', async () => {
    const jobs: CampaignJob[] = [];
    const queue: PushQueue = {
      enqueue: async (j) => {
        jobs.push(j);
      },
    };
    const uc = new SendCampaignUseCase(repoWith(['u1', 'u2', 'u3']), queue);

    const result = await uc.execute('Başlık', 'Gövde');

    expect(result).toEqual({ recipients: 3, queued: 3 });
    expect(jobs).toEqual([
      { userId: 'u1', title: 'Başlık', body: 'Gövde' },
      { userId: 'u2', title: 'Başlık', body: 'Gövde' },
      { userId: 'u3', title: 'Başlık', body: 'Gövde' },
    ]);
  });

  it('boş segment → hiç enqueue yok, queued 0', async () => {
    let calls = 0;
    const queue: PushQueue = {
      enqueue: async () => {
        calls++;
      },
    };
    const result = await new SendCampaignUseCase(repoWith([]), queue).execute('t', 'b');
    expect(result).toEqual({ recipients: 0, queued: 0 });
    expect(calls).toBe(0);
  });

  it('platform filtresi repository’ye iletilir (segment daraltma)', async () => {
    const seen: Array<string | undefined> = [];
    const queue: PushQueue = { enqueue: async () => {} };
    await new SendCampaignUseCase(
      repoWith(['u1'], (p) => seen.push(p)),
      queue,
    ).execute('t', 'b', 'ios');
    expect(seen).toEqual(['ios']);
  });
});

describe('InlinePushQueue (Redis’siz fallback — dev/test)', () => {
  it('ÇEKİRDEK: enqueue teslimi HEMEN yapar (SendNotification doğru argümanla çağrılır)', async () => {
    const calls: Array<{ userId: string; message: unknown }> = [];
    const send = {
      execute: async (userId: string, message: unknown) => {
        calls.push({ userId, message });
        return { sent: 1, failed: 0 };
      },
    } as unknown as SendNotificationUseCase;

    await new InlinePushQueue(send).enqueue({ userId: 'u1', title: 'T', body: 'B' });

    expect(calls).toEqual([{ userId: 'u1', message: { title: 'T', body: 'B' } }]);
  });
});
