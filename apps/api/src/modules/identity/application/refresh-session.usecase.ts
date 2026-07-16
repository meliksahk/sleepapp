import { audienceForKind } from '../domain/user.entity';
import type { IssuedSession } from '../domain/user.entity';
import { InvalidRefreshTokenError, RefreshTokenReuseError } from '../domain/errors';
import type { Clock, RefreshTokenRepository, TokenHasher, UserRepository } from '../domain/ports';
import type { SessionMinter } from './session-minter';

/**
 * Refresh akışı — rotation + reuse-detection + kısa yarış toleransı (docs/02 §2.1).
 *
 * GRACE WINDOW — NEDEN VAR: rotasyon, aynı token'la gelen İKİNCİ isteği "çalıntı"
 * sayar. Ama iki sekmenin aynı anda yenilemeye kalkması MEŞRU ve olağandır; sert
 * kural bu kullanıcıyı sistemden atıyordu (#117'de fark edildi). Bu yüzden rotasyondan
 * hemen sonraki kısa pencerede (REFRESH_REUSE_GRACE_MS) yeniden kullanım, hırsızlık
 * değil YARIŞ kabul edilir ve aynı aile içinde yeni bir çift verilir.
 *
 * BEDELİ (açıkça): token'ı çalan biri, meşru istemcinin rotasyonundan sonraki bu kısa
 * pencerede kullanırsa yakalanmaz. Pencere dışında hâlâ yakalanır ve aile düşer.
 * Bu, endüstride yerleşik bir takas (Auth0 "reuse interval"). Katı davranış isteyen
 * REFRESH_REUSE_GRACE_MS=0 verir — kapatılabilir olması bilinçli.
 *
 * ÇIKIŞI BOZMAMASI KRİTİK: çıkış (ve reuse) AİLEYİ düşürür → ailede aktif token
 * KALMAZ. Grace yalnızca "aile hâlâ canlı" iken uygulanır; yani normal rotasyondan
 * sonra. Aksi halde çıkıştan sonraki 10sn içinde refresh yeni oturum basar ve çıkış
 * sessizce çalışmaz olurdu.
 */
export class RefreshSessionUseCase {
  constructor(
    private readonly refreshTokens: RefreshTokenRepository,
    private readonly users: UserRepository,
    private readonly hasher: TokenHasher,
    private readonly clock: Clock,
    private readonly sessions: SessionMinter,
    /** 0 = katı davranış (yarış toleransı yok). Bkz. sınıf yorumu. */
    private readonly reuseGraceMs: number,
  ) {}

  async execute(rawRefreshToken: string): Promise<IssuedSession> {
    const hash = this.hasher.hash(rawRefreshToken);
    const record = await this.refreshTokens.findByHash(hash);
    if (!record) {
      throw new InvalidRefreshTokenError();
    }

    const now = this.clock.now();

    if (record.revokedAt !== null) {
      // `> 0` şart: grace=0 KATI demektir. Yalnızca `<=` yazsaydık, aynı anda gelen
      // ikinci istek (fark = 0) katı modda bile tolere edilirdi — pencere kapalıyken
      // sızan bir delik. (Donmuş saatli test yakaladı.)
      const withinGrace =
        this.reuseGraceMs > 0 && now.getTime() - record.revokedAt.getTime() <= this.reuseGraceMs;
      // Aile canlı mı? Çıkış/reuse aileyi komple düşürür → aktif token kalmaz.
      // Bu kontrol olmadan grace, çıkışı 10sn boyunca etkisiz kılardı.
      const familyAlive =
        withinGrace && (await this.refreshTokens.hasActiveInFamily(record.familyId, now));

      if (!familyAlive) {
        // Gerçek reuse (pencere dışı VEYA ölü aile) → çalıntı; tüm aileyi düşür.
        await this.refreshTokens.revokeFamily(record.familyId, now);
        throw new RefreshTokenReuseError();
      }
      // İyi niyetli yarış: aşağıda aynı aile içinde yeni çift verilir. Bu token
      // zaten iptal — tekrar iptal etmeye çalışmayız (markRevoked idempotent olsa da).
      return this.mintFor(record.userId, record.familyId);
    }

    if (record.expiresAt.getTime() <= now.getTime()) {
      throw new InvalidRefreshTokenError();
    }

    /**
     * SIRA KRİTİK — ÖNCE BAS, SONRA İPTAL ET.
     *
     * Tersi (önce iptal, sonra bas) ailede bir AN aktif token bırakmaz. Tam o
     * boşluğa düşen ikinci sekme, "aile ölü" görüp yarışı REUSE sanar ve aileyi
     * düşürür — grace window'u işlevsiz kılar. Bu, gerçek eşzamanlı istekle
     * ölçülerek bulundu (birim testler yakalayamıyordu: sıralılar).
     *
     * Bu sırada mint başarısız olursa eski token geçerli kalır (oturum verilmedi,
     * kimse mağdur olmadı). markRevoked başarısız olursa eski token bir süre daha
     * yaşar — rotasyon zayıflar ama kimse dışarı atılmaz. İki hata da sessiz
     * kilitlenmeden iyidir.
     */
    const session = await this.mintFor(record.userId, record.familyId);
    await this.refreshTokens.markRevoked(record.id, now);
    return session;
  }

  private async mintFor(userId: string, familyId: string): Promise<IssuedSession> {
    const user = await this.users.findById(userId);
    if (!user) {
      throw new InvalidRefreshTokenError();
    }
    return this.sessions.mint({
      userId: user.id,
      roles: user.roles,
      familyId,
      // Rol/tür değişimi refresh'te yürürlüğe girer: admin yapılan hesap bir sonraki
      // refresh'te 'admin' audience'ı alır, geri alınan da kaybeder.
      aud: audienceForKind(user.kind),
    });
  }
}
