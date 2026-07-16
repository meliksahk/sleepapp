import { GetShareFunnelUseCase } from '../../src/modules/analytics/application/get-share-funnel.usecase';
import type {
  AnalyticsEventRepository,
  ShareFunnelCounts,
} from '../../src/modules/analytics/domain/ports';

/**
 * Paylaşım hunisi oranı — özellikle SIFIRA BÖLME kararı.
 *
 * e2e'de test EDİLEMEZ: paylaşılan test DB'sinde başka testlerin olayları durur,
 * `completed` asla 0 olmaz. Bu dal ancak burada sabitlenebilir — ve tam da bu dal
 * "kimse paylaşmıyor" diye yanlış bir ifadeye dönüşebilecek olan.
 */
class FakeRepo implements AnalyticsEventRepository {
  constructor(private readonly counts: ShareFunnelCounts) {}
  saveBatch(): Promise<number> {
    throw new Error('kullanılmaz');
  }
  async shareFunnel(): Promise<ShareFunnelCounts> {
    return this.counts;
  }
}

const funnelWith = (completed: number, shared: number) =>
  new GetShareFunnelUseCase(new FakeRepo({ completed, shared }));

describe('GetShareFunnelUseCase', () => {
  it('ÇEKİRDEK: kimse testi tamamlamadıysa oran NULL — 0 DEĞİL', async () => {
    // 0 göstermek "kimse paylaşmıyor" demektir. Ama kimse test bile yapmamışsa
    // bu YANLIŞ bir ifadedir: paylaşım oranı TANIMSIZDIR. Panel null'ı "—" gösterir.
    const f = await funnelWith(0, 0).execute();
    expect(f.rate).toBeNull();
    expect(f.completed).toBe(0);
    expect(f.shared).toBe(0);
  });

  it('herkes paylaştıysa 1.0', async () => {
    expect((await funnelWith(10, 10).execute()).rate).toBe(1);
  });

  it('kimse paylaşmadıysa 0 (bu SEFER doğru ifade: test yapan var, paylaşan yok)', async () => {
    expect((await funnelWith(10, 0).execute()).rate).toBe(0);
  });

  it('kısmi oran hesaplanır', async () => {
    expect((await funnelWith(8, 2).execute()).rate).toBe(0.25);
  });

  it('ham sayılar da döner (oran tek başına yanıltıcı olabilir: 1/1 = %100)', async () => {
    const f = await funnelWith(1, 1).execute();
    expect(f).toEqual({ completed: 1, shared: 1, rate: 1 });
  });

  it('oran YUVARLANMAZ — sunum kararı panelin işi', async () => {
    expect((await funnelWith(3, 1).execute()).rate).toBeCloseTo(0.3333333, 6);
  });
});
