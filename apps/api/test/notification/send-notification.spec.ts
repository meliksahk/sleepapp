import { SendNotificationUseCase } from '../../src/modules/notification/application/send-notification.usecase';
import type { DeviceTokenRepository } from '../../src/modules/notification/domain/device-token';
import type {
  PushMessage,
  PushSender,
  PushTarget,
} from '../../src/modules/notification/domain/push-sender';
import { LogPushSender } from '../../src/modules/notification/infrastructure/log-push-sender';

const msg: PushMessage = { title: 'Gece raporun hazır', body: 'Dünkü uykunu gör.' };

class FakeRepo implements DeviceTokenRepository {
  constructor(private readonly targets: PushTarget[]) {}
  register(): Promise<void> {
    throw new Error('kullanılmaz');
  }
  async findTokensByUser(): Promise<PushTarget[]> {
    return this.targets;
  }
}

describe('SendNotificationUseCase (fan-out)', () => {
  it('kullanıcının tüm cihazlarına gönderir (sent = token sayısı)', async () => {
    const repo = new FakeRepo([
      { token: 't1', platform: 'ios' },
      { token: 't2', platform: 'android' },
      { token: 't3', platform: 'ios' },
    ]);
    const calls: PushTarget[] = [];
    const sender: PushSender = {
      send: async (target) => {
        calls.push(target);
      },
    };

    const result = await new SendNotificationUseCase(repo, sender).execute('u-1', msg);

    expect(result).toEqual({ sent: 3, failed: 0 });
    expect(calls.map((c) => c.token)).toEqual(['t1', 't2', 't3']);
  });

  it('bir hedef başarısız olsa da diğerleri gönderilir (izole)', async () => {
    const repo = new FakeRepo([
      { token: 'ok1', platform: 'ios' },
      { token: 'bad', platform: 'android' },
      { token: 'ok2', platform: 'ios' },
    ]);
    const sent: string[] = [];
    const sender: PushSender = {
      send: async (target) => {
        if (target.token === 'bad') throw new Error('süresi dolmuş token');
        sent.push(target.token);
      },
    };

    const result = await new SendNotificationUseCase(repo, sender).execute('u-1', msg);

    expect(result).toEqual({ sent: 2, failed: 1 });
    expect(sent).toEqual(['ok1', 'ok2']); // hata diğerlerini durdurmadı
  });

  it('cihaz yoksa gönderim yapılmaz', async () => {
    const repo = new FakeRepo([]);
    let called = false;
    const sender: PushSender = {
      send: async () => {
        called = true;
      },
    };

    const result = await new SendNotificationUseCase(repo, sender).execute('u-1', msg);

    expect(result).toEqual({ sent: 0, failed: 0 });
    expect(called).toBe(false);
  });
});

describe('LogPushSender', () => {
  it('gönderim hata fırlatmaz (log-adaptörü)', async () => {
    const sender = new LogPushSender();
    await expect(sender.send({ token: 'abcd1234', platform: 'ios' }, msg)).resolves.toBeUndefined();
  });
});
