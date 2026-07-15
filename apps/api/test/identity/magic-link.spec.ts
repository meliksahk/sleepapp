import { buildIdentityStack } from './harness';
import {
  RandomOpaqueTokenGenerator,
  UuidIdGenerator,
} from '../../src/modules/identity/infrastructure/crypto-adapters';
import { InMemoryOneTimeTokenRepository } from '../../src/modules/identity/infrastructure/in-memory.repositories';
import { RequestEmailUpgradeUseCase } from '../../src/modules/identity/application/request-email-upgrade.usecase';
import { VerifyEmailUpgradeUseCase } from '../../src/modules/identity/application/verify-email-upgrade.usecase';
import {
  EmailAlreadyTakenError,
  InvalidMagicLinkError,
} from '../../src/modules/identity/domain/errors';
import type { Mailer } from '../../src/modules/identity/domain/ports';

async function buildEmailStack() {
  const s = await buildIdentityStack();
  const ott = new InMemoryOneTimeTokenRepository();
  const sent: Array<{ email: string; link: string }> = [];
  const mailer: Mailer = {
    async sendMagicLink(email, link) {
      sent.push({ email, link });
    },
  };
  const request = new RequestEmailUpgradeUseCase(
    s.users,
    ott,
    mailer,
    new UuidIdGenerator(),
    s.clock,
    s.hasher,
    new RandomOpaqueTokenGenerator(),
    { ttlSeconds: 900, baseUrl: 'http://x/verify' },
  );
  const verify = new VerifyEmailUpgradeUseCase(s.users, ott, s.clock, s.hasher);
  return { s, request, verify, sent };
}

describe('Magic link e-posta yükseltme (in-memory)', () => {
  it('talep → mailer link alır → doğrula → kullanıcı registered olur', async () => {
    const { s, request, verify, sent } = await buildEmailStack();
    const session = await s.registerDevice.execute({ fingerprint: 'ml-1', platform: 'ios' });

    const raw = await request.execute(session.userId, 'A@B.com');
    expect(sent).toHaveLength(1);
    expect(sent[0]?.email).toBe('a@b.com'); // normalize
    expect(sent[0]?.link).toContain(raw);

    const res = await verify.execute(raw);
    expect(res.userId).toBe(session.userId);
    expect(res.email).toBe('a@b.com');

    const upgraded = await s.users.findByEmail('a@b.com');
    expect(upgraded?.id).toBe(session.userId);
    expect(upgraded?.kind).toBe('registered');
  });

  it('token tek kullanımlık — ikinci doğrulama geçersiz', async () => {
    const { s, request, verify } = await buildEmailStack();
    const session = await s.registerDevice.execute({ fingerprint: 'ml-2', platform: 'ios' });
    const raw = await request.execute(session.userId, 'c@d.com');
    await verify.execute(raw);
    await expect(verify.execute(raw)).rejects.toBeInstanceOf(InvalidMagicLinkError);
  });

  it('bilinmeyen token geçersiz', async () => {
    const { verify } = await buildEmailStack();
    await expect(verify.execute('yok')).rejects.toBeInstanceOf(InvalidMagicLinkError);
  });

  it('başka kullanıcının kullandığı e-posta için talep reddedilir', async () => {
    const { s, request } = await buildEmailStack();
    const a = await s.registerDevice.execute({ fingerprint: 'ml-3', platform: 'ios' });
    const b = await s.registerDevice.execute({ fingerprint: 'ml-4', platform: 'ios' });
    await s.users.upgradeToEmail(a.userId, 'taken@x.com', new Date());
    await expect(request.execute(b.userId, 'taken@x.com')).rejects.toBeInstanceOf(
      EmailAlreadyTakenError,
    );
  });
});
