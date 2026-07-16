import type { AnalyticsEventRepository } from '../domain/ports';

/** Paylaşım hunisi — panel panosu (docs/03 A3). Analytics'in PUBLIC servisi. */
export interface ShareFunnel {
  /** Archetype testini tamamlayan BENZERSİZ kullanıcı sayısı. */
  readonly completed: number;
  /** Kartını paylaşan benzersiz kullanıcı sayısı. */
  readonly shared: number;
  /**
   * shared / completed. **null olabilir:** kimse testi tamamlamadıysa oran
   * TANIMSIZDIR — 0 göstermek "kimse paylaşmıyor" demek olurdu ve bu YANLIŞ bir
   * ifadedir (henüz kimse test bile yapmamışken). Panel null'ı "—" gösterir.
   */
  readonly rate: number | null;
}

/**
 * Viral kancanın sağlığı (CLAUDE.md §1.1: "viral kancalar süs değil çekirdek
 * özelliktir"). Ürünün üzerine bahis oynadığı döngü buysa, ölçülmeli.
 *
 * ORAN BURADA HESAPLANIR, SQL'DE DEĞİL: sıfıra bölme bir ÜRÜN kararıdır
 * ("tanımsız" mı "0" mı?), veritabanı sorusu değil.
 */
export class GetShareFunnelUseCase {
  constructor(private readonly repo: AnalyticsEventRepository) {}

  async execute(): Promise<ShareFunnel> {
    const { completed, shared } = await this.repo.shareFunnel();
    return {
      completed,
      shared,
      rate: completed === 0 ? null : shared / completed,
    };
  }
}
