import {
  MAX_MOOD_FILTER,
  parseMoodFilter,
  type AudioAsset,
  type AudioAssetFilter,
  type AudioAssetRepository,
} from '../../src/modules/content/domain/audio-asset';
import { ListAudioAssetsUseCase } from '../../src/modules/content/application/list-audio-assets.usecase';
import { GetAudioAssetUseCase } from '../../src/modules/content/application/get-audio-asset.usecase';
import type { AssetUrlSigner } from '../../src/modules/content/domain/soundscape';

const asset = (id: string, over: Partial<AudioAsset> = {}): AudioAsset => ({
  id,
  key: `demo/${id}.wav`,
  title: id,
  genre: 'ambient',
  mood: ['calm'],
  durationSeconds: 10,
  license: 'self-produced',
  source: 'NOCTA audio engine',
  ...over,
});

/** Filtreyi KAYDEDEN sahte repo — use case'in ne sorduğunu görebilelim. */
class FakeRepo implements AudioAssetRepository {
  lastFilter: AudioAssetFilter | null = null;
  constructor(private readonly rows: AudioAsset[]) {}
  async list(filter: AudioAssetFilter): Promise<AudioAsset[]> {
    this.lastFilter = filter;
    return this.rows;
  }
  async findById(id: string): Promise<AudioAsset | null> {
    return this.rows.find((r) => r.id === id) ?? null;
  }
}

const signer: AssetUrlSigner = {
  presignedGetUrl: async (bucket, key, ttl) => `https://minio.test/${bucket}/${key}?ttl=${ttl}`,
};

describe('parseMoodFilter', () => {
  it('virgülle ayrık listeyi normalize eder (trim + küçük harf + tekilleştir)', () => {
    expect(parseMoodFilter(' Calm , focus,CALM ')).toEqual(['calm', 'focus']);
  });

  it('boş/anlamsız girdide undefined döner — "filtre yok" ile "boş filtre" karışmasın', () => {
    expect(parseMoodFilter(undefined)).toBeUndefined();
    expect(parseMoodFilter('')).toBeUndefined();
    expect(parseMoodFilter(' , , ')).toBeUndefined();
  });

  it(`en fazla ${MAX_MOOD_FILTER} mood alır (sorgu şişmesi kapısı)`, () => {
    const many = Array.from({ length: MAX_MOOD_FILTER + 5 }, (_, i) => `m${i}`).join(',');
    expect(parseMoodFilter(many)).toHaveLength(MAX_MOOD_FILTER);
  });
});

describe('ListAudioAssetsUseCase', () => {
  it('filtreyi repo’ya olduğu gibi geçirir', async () => {
    const repo = new FakeRepo([asset('a')]);
    const list = await new ListAudioAssetsUseCase(repo).execute({
      genre: 'ambient',
      moods: ['calm'],
    });
    expect(list).toHaveLength(1);
    expect(repo.lastFilter).toEqual({ genre: 'ambient', moods: ['calm'] });
  });

  it('argümansız çağrıda boş filtre kullanır (tüm katalog)', async () => {
    const repo = new FakeRepo([asset('a'), asset('b')]);
    await new ListAudioAssetsUseCase(repo).execute();
    expect(repo.lastFilter).toEqual({});
  });
});

describe('GetAudioAssetUseCase', () => {
  it('presigned URL üretir ve DEPOLAMA ANAHTARINI kullanır (URL DB’de tutulmaz)', async () => {
    const repo = new FakeRepo([asset('a')]);
    const res = await new GetAudioAssetUseCase(repo, signer, 'audio-assets').execute('a');
    expect(res).not.toBeNull();
    expect(res!.url).toContain('audio-assets/demo/a.wav');
    expect(res!.expiresInSeconds).toBeGreaterThan(0);
  });

  it('kayıt yoksa null (controller 404’e çevirir; use case HTTP bilmez)', async () => {
    const repo = new FakeRepo([]);
    const res = await new GetAudioAssetUseCase(repo, signer, 'audio-assets').execute('yok');
    expect(res).toBeNull();
  });
});
