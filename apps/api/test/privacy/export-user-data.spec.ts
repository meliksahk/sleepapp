import {
  ExportUserDataUseCase,
  type ExportSources,
} from '../../src/modules/privacy/application/export-user-data.usecase';

describe('ExportUserDataUseCase (GDPR export, D-7)', () => {
  it('ÇEKİRDEK: tüm bölümleri TEK userId ile toplar (izolasyon tasarım gereği)', async () => {
    const seen: string[] = [];
    const sources: ExportSources = {
      profile: async (u) => {
        seen.push(u);
        return { displayName: 'Gece Kuşu' };
      },
      archetypeResults: async (u) => {
        seen.push(u);
        return [{ archetypeSlug: 'deep-ocean' }];
      },
      sleepSessions: async (u) => {
        seen.push(u);
        return [{ id: 's1' }];
      },
      sessions: async (u) => {
        seen.push(u);
        return [{ fingerprint: 'fp-1' }];
      },
    };

    const res = await new ExportUserDataUseCase(sources).execute('user-1');

    // Her kaynak token'daki sub ile çağrıldı — istemciden id kabul edilmez.
    expect(seen).toEqual(['user-1', 'user-1', 'user-1', 'user-1']);
    expect(res.profile).toEqual({ displayName: 'Gece Kuşu' });
    expect(res.archetypeResults).toEqual([{ archetypeSlug: 'deep-ocean' }]);
    expect(res.sleepSessions).toEqual([{ id: 's1' }]);
    expect(res.account.sessions).toEqual([{ fingerprint: 'fp-1' }]);
    // exportedAt geçerli ISO zaman damgası.
    expect(new Date(res.exportedAt).getTime()).toBeGreaterThan(0);
  });

  it('boş kullanıcı: bölümler boş ama yapı eksiksiz', async () => {
    const empty: ExportSources = {
      profile: async () => ({ displayName: null }),
      archetypeResults: async () => [],
      sleepSessions: async () => [],
      sessions: async () => [],
    };
    const res = await new ExportUserDataUseCase(empty).execute('user-2');
    expect(res.archetypeResults).toEqual([]);
    expect(res.sleepSessions).toEqual([]);
    expect(res.account.sessions).toEqual([]);
    expect(res.profile).toEqual({ displayName: null });
  });
});
