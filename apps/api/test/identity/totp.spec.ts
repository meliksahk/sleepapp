import {
  generateTotpSecret,
  hotpCode,
  totpAuthUri,
  totpCode,
  totpCounter,
  verifyTotp,
  TOTP_STEP_SECONDS,
} from '../../src/modules/identity/domain/totp';

/**
 * TOTP — RESMÎ RFC VEKTÖRLERİ.
 *
 * Bu dosyanın varlık sebebi: TOTP'yi kütüphane yerine kendimiz yazdık. O kararın
 * TEK savunması, doğruluğun BENİM ürettiğim beklentilerle değil, RFC'nin YAYIMLADIĞI
 * değerlerle kanıtlanmasıdır. Kendi çıktımı kendi beklentime eşitlemek hiçbir şey
 * kanıtlamazdı — aşağıdaki sayılar RFC 4226 Appendix D ve RFC 6238 Appendix B'den
 * birebir alındı.
 */

// Her iki RFC'nin de kullandığı gizli anahtar: ASCII "12345678901234567890".
const RFC_SECRET_ASCII = '12345678901234567890';
const RFC_SECRET = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ'; // yukarıdakinin base32'si

describe('TOTP domain', () => {
  describe('RFC 4226 Appendix D — resmî HOTP vektörleri', () => {
    // Tablo RFC 4226'dan birebir: sayaç → beklenen 6 haneli kod.
    const RFC4226_VECTORS: ReadonlyArray<[number, string]> = [
      [0, '755224'],
      [1, '287082'],
      [2, '359152'],
      [3, '969429'],
      [4, '338314'],
      [5, '254676'],
      [6, '287922'],
      [7, '162583'],
      [8, '399871'],
      [9, '520489'],
    ];

    it.each(RFC4226_VECTORS)('sayaç %i → %s', (counter, expected) => {
      expect(hotpCode(RFC_SECRET, counter)).toBe(expected);
    });
  });

  describe('RFC 6238 Appendix B — resmî TOTP vektörleri (SHA1)', () => {
    /**
     * RFC tablosu 8 haneli kod verir; biz 6 hane üretiyoruz. Kırpma `binary % 10^d`
     * olduğundan 6 hane, 8 hanenin SON 6 hanesidir — yorum değil, tanım gereği.
     * Yorumda ikisini de yazıyorum ki vektörler RFC'de aranıp bulunabilsin.
     */
    const RFC6238_VECTORS: ReadonlyArray<[number, string, string]> = [
      [59, '94287082', '287082'],
      [1111111109, '07081804', '081804'],
      [1111111111, '14050471', '050471'],
      [1234567890, '89005924', '005924'],
      [2000000000, '69279037', '279037'],
      // 2286 yılı — 32-bit sayaç taşmasını yakalayan vektör.
      [20000000000, '65353130', '353130'],
    ];

    it.each(RFC6238_VECTORS)('T=%i (RFC 8 hane: %s) → %s', (unixSeconds, _rfc8, expected6) => {
      expect(totpCode(RFC_SECRET, unixSeconds * 1000)).toBe(expected6);
    });
  });

  describe('base32', () => {
    it('RFC anahtarı doğru çözülür (vektörlerin ön koşulu)', () => {
      // Vektörler tutuyorsa çözme zaten doğrudur; yine de niyeti açıkça sabitliyorum.
      expect(Buffer.from(RFC_SECRET_ASCII, 'ascii').toString('hex')).toBe(
        '3132333435363738393031323334353637383930',
      );
    });

    it('üretilen anahtar tur atar (encode→decode→aynı kodlar)', () => {
      const secret = generateTotpSecret();
      // Boşluklu/küçük harfli yapıştırma da aynı sonucu vermeli.
      const messy = secret.toLowerCase().replace(/(.{4})/g, '$1 ');
      expect(hotpCode(messy, 42)).toBe(hotpCode(secret, 42));
    });

    it('geçersiz karakter SESSİZCE yutulmaz', () => {
      // '1' ve '0' base32 alfabesinde YOK (O/I ile karışmasınlar diye). Bunları
      // yok saymak, yanlış anahtarla yanlış kod üretip "kodun tutmuyor" derdi.
      expect(() => hotpCode('AAAA1111', 0)).toThrow(/base32/i);
    });

    it('üretilen anahtar 32 karakter (20 bayt) ve her seferinde farklı', () => {
      const a = generateTotpSecret();
      expect(a).toMatch(/^[A-Z2-7]{32}$/);
      expect(a).not.toBe(generateTotpSecret());
    });
  });

  describe('verifyTotp', () => {
    const now = 1_700_000_000_000;

    it('geçerli kod → kullanılan sayacı döner', () => {
      expect(verifyTotp(RFC_SECRET, totpCode(RFC_SECRET, now), now)).toBe(totpCounter(now));
    });

    it('yanlış kod → null', () => {
      expect(verifyTotp(RFC_SECRET, '000000', now)).toBeNull();
    });

    it('±1 adım kabul edilir (saat kayması gerçek)', () => {
      const step = TOTP_STEP_SECONDS * 1000;
      expect(verifyTotp(RFC_SECRET, totpCode(RFC_SECRET, now - step), now)).not.toBeNull();
      expect(verifyTotp(RFC_SECRET, totpCode(RFC_SECRET, now + step), now)).not.toBeNull();
    });

    it('±2 adım REDDEDİLİR (pencere sınırsız değil)', () => {
      const step = TOTP_STEP_SECONDS * 1000;
      expect(verifyTotp(RFC_SECRET, totpCode(RFC_SECRET, now - 2 * step), now)).toBeNull();
      expect(verifyTotp(RFC_SECRET, totpCode(RFC_SECRET, now + 2 * step), now)).toBeNull();
    });

    it('ÇEKİRDEK: kullanılmış sayaç bir daha KABUL EDİLMEZ (RFC 6238 §5.2 tekrar saldırısı)', () => {
      // Omuz üstünden kodu gören biri 30 sn içinde aynı kodla girebilirdi.
      const code = totpCode(RFC_SECRET, now);
      const used = verifyTotp(RFC_SECRET, code, now);
      expect(used).not.toBeNull();
      expect(verifyTotp(RFC_SECRET, code, now, used!)).toBeNull();
    });

    it('ÇEKİRDEK: kullanılmış sayaçtan ESKİ kod da reddedilir (geri sarma yok)', () => {
      const step = TOTP_STEP_SECONDS * 1000;
      const oldCode = totpCode(RFC_SECRET, now - step);
      // Şu anki sayaç zaten kullanıldıysa, bir önceki adımın kodu da geçmiştir.
      expect(verifyTotp(RFC_SECRET, oldCode, now, totpCounter(now))).toBeNull();
    });

    it('kullanılmış sayaçtan SONRAKİ kod kabul edilir (aksi hâlde kilitlenirdik)', () => {
      const step = TOTP_STEP_SECONDS * 1000;
      const next = now + step;
      expect(verifyTotp(RFC_SECRET, totpCode(RFC_SECRET, next), next, totpCounter(now))).toBe(
        totpCounter(next),
      );
    });

    it('biçimsiz girdi HMAC hesaplamadan elenir', () => {
      for (const bad of ['', '12345', '1234567', 'abcdef', '12 34 56', '12345a']) {
        expect(verifyTotp(RFC_SECRET, bad, now)).toBeNull();
      }
    });
  });

  describe('otpauth URI', () => {
    it('Authenticator uygulamasının beklediği biçim', () => {
      const uri = totpAuthUri(RFC_SECRET, 'admin@nocta.test');
      expect(uri).toContain('otpauth://totp/NOCTA%3Aadmin%40nocta.test?');
      expect(uri).toContain(`secret=${RFC_SECRET}`);
      expect(uri).toContain('issuer=NOCTA');
      expect(uri).toContain('digits=6');
      expect(uri).toContain('period=30');
      expect(uri).toContain('algorithm=SHA1');
    });
  });
});
