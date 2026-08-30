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

/** Topluluk satırı (`user_sounds`, yalnızca status='approved' olanlar buraya gelir). */
interface CommunityRow {
  id: string;
  /** Prisma modelinde alan adı storage_key'dir; katalog sözleşmesi `key` der. */
  storage_key: string;
  title: string;
  duration_seconds: number;
}

/**
 * `id` alanı DB'de uuid. Rastgele bir dizgi ('abc') ile sorgu atmak Prisma'da
 * ARAMA SONUCU DEĞİL, İSTİSNA üretir (P2023: inconsistent column data) → üst
 * 500 dönerdi. Oysa "olmayan kayıt" 404'tür. Bu yüzden biçim önce burada elenir.
 */
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export class PrismaAudioAssetRepository implements AudioAssetRepository {
  constructor(private readonly prisma: PrismaService) {}

  async list(filter: AudioAssetFilter): Promise<AudioAsset[]> {
    const rows = await this.prisma.audio_assets.findMany({
      where: {
        ...(filter.genre ? { genre: filter.genre } : {}),
        // `hasSome` = Postgres `&&` (örtüşme): mood'lardan HERHANGİ BİRİ eşleşsin.
        // `hasEvery` olsaydı "sakin VE odak" arardık — kullanıcı öyle düşünmüyor.
        ...(filter.moods && filter.moods.length > 0
          ? { mood: { hasSome: [...filter.moods] } }
          : {}),
      },
      orderBy: { created_at: 'desc' },
    });
    const curated = rows.map(toAsset);

    // ── Topluluk köprüsü (3a): ONAYLI user_sounds katalogda görünür. ──
    //
    // Modül sınırına saygı: community'nin REPO'SUNA dokunulmaz; aynı
    // PrismaService üzerinden kendi sorgusu yapılır ve satır KATALOG
    // SÖZLEŞMESİNE çevrilir. Onaysız içerik bu listede ASLA görünmez —
    // moderasyon tam da bu kapıdır. genre='community', lisans 'user-upload':
    // dosyanın nereden geldiği veride kalır (§6 mağaza uyumu).
    const approved = await this.prisma.user_sounds.findMany({
      where: { status: 'approved' },
      orderBy: { created_at: 'desc' },
    });

    return [...curated, ...approved.map(toCommunityAsset)];
  }

  async findById(id: string): Promise<AudioAsset | null> {
    if (!UUID_RE.test(id)) return null;
    const row = await this.prisma.audio_assets.findUnique({ where: { id } });
    if (row) return toAsset(row);
    // Katalogda yoksa onaylı topluluk sesine bak: detay/presigned GET yolu
    // ("Bu sesi çal") topluluk satırları için de AYNI ucu kullanır.
    const community = await this.prisma.user_sounds.findFirst({
      where: { id, status: 'approved' },
    });
    return community ? toCommunityAsset(community) : null;
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

/** Topluluk satırını katalog sözleşmesine çevirir — TEK yerde (liste + detay). */
function toCommunityAsset(row: CommunityRow): AudioAsset {
  return {
    id: row.id,
    key: row.storage_key,
    title: row.title,
    genre: 'community',
    mood: [],
    durationSeconds: row.duration_seconds,
    license: 'user-upload',
    source: 'community',
  };
}
