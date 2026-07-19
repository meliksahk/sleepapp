import type { AudioAsset, AudioAssetFilter, AudioAssetRepository } from '../domain/audio-asset';
import type { PrismaService } from '../../../shared/infra/prisma.service';

interface AudioAssetRow {
  id: string;
  key: string;
  title: string;
  genre: string;
  mood: string[];
  duration_seconds: number;
  license: string;
  source: string;
}

/**
 * `id` alanı DB'de uuid. Rastgele bir dizgi ('abc') ile sorgu atmak Prisma'da
 * ARAMA SONUCU DEĞİL, İSTİSNA üretir (P2023: inconsistent column data) → uç 500
 * dönerdi. Oysa "olmayan kayıt" 404'tür. Bu yüzden biçim önce burada elenir.
 */
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export class PrismaAudioAssetRepository implements AudioAssetRepository {
  constructor(private readonly prisma: PrismaService) {}

  async list(filter: AudioAssetFilter): Promise<AudioAsset[]> {
    const rows = await this.prisma.audio_assets.findMany({
      where: {
        ...(filter.genre ? { genre: filter.genre } : {}),
        // `hasSome` = Postgres `&&` (örtüşme): mood'lardan HERHANGİ BİRİ eşleşsin.
        // `hasEvery` olsaydı "sakin VE odak" arardı — kullanıcı öyle düşünmüyor.
        ...(filter.moods && filter.moods.length > 0
          ? { mood: { hasSome: [...filter.moods] } }
          : {}),
      },
      orderBy: { created_at: 'desc' },
    });
    return rows.map(toAsset);
  }

  async findById(id: string): Promise<AudioAsset | null> {
    if (!UUID_RE.test(id)) return null;
    const row = await this.prisma.audio_assets.findUnique({ where: { id } });
    return row ? toAsset(row) : null;
  }
}

function toAsset(row: AudioAssetRow): AudioAsset {
  return {
    id: row.id,
    key: row.key,
    title: row.title,
    genre: row.genre,
    mood: row.mood,
    durationSeconds: row.duration_seconds,
    license: row.license,
    source: row.source,
  };
}
