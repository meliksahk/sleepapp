import type { ArchetypeResult, ArchetypeResultRepository } from '../domain/ports';

/**
 * Kullanıcının archetype sonuç GEÇMİŞİ (yeniden eskiye).
 *
 * Neden: testi tekrar etmek yeni bir kayıt üretir ve bu kayıtlar saklanıyordu,
 * ama yalnızca EN SON sonuç erişilebiliyordu — geçmiş kullanıcının kendi verisi
 * olmasına rağmen hiçbir yerden görünmüyordu. Kimlik zamanla değişebilir
 * ("Deep Ocean → Dawn Chaser"); bunu göstermek ürünün çekirdek anlatısı.
 * Ayrıca hesap veri dışa aktarımının (D-7) ihtiyaç duyacağı parça.
 */
export class ListResultsUseCase {
  constructor(private readonly results: ArchetypeResultRepository) {}

  execute(userId: string): Promise<ArchetypeResult[]> {
    return this.results.listByUserId(userId);
  }
}
