import { isOriginAllowed, parseCorsOrigins } from './cors';

/**
 * CORS yanlış yapılandırması SESSİZDİR: ya web kırılır (tarayıcıda ERR_FAILED,
 * sunucu logunda hiçbir şey), ya da API herkese açılır. İkisi de test edilmeli.
 */
describe('parseCorsOrigins', () => {
  it('virgülle ayrık listeyi böler ve boşlukları kırpar', () => {
    expect(parseCorsOrigins('http://a.test, http://b.test')).toEqual([
      'http://a.test',
      'http://b.test',
    ]);
  });

  it('sondaki eğik çizgiyi atar (kaynak karşılaştırması tam eşleşmedir)', () => {
    // Tarayıcı Origin başlığında ASLA sondaki / göndermez; env'de yazılırsa
    // karşılaştırma sessizce başarısız olurdu.
    expect(parseCorsOrigins('http://a.test/,http://b.test//')).toEqual([
      'http://a.test',
      'http://b.test',
    ]);
  });

  it('boş girdileri eler (sondaki virgül / boş env kazası)', () => {
    expect(parseCorsOrigins('http://a.test,,  ,')).toEqual(['http://a.test']);
    expect(parseCorsOrigins('')).toEqual([]);
    expect(parseCorsOrigins('   ')).toEqual([]);
  });
});

describe('isOriginAllowed', () => {
  const allow = ['http://localhost:3003', 'https://nocta.app'];

  it('izin listesindeki kaynağa izin verir', () => {
    expect(isOriginAllowed('http://localhost:3003', allow)).toBe(true);
    expect(isOriginAllowed('https://nocta.app', allow)).toBe(true);
  });

  it('listede olmayanı REDDEDER', () => {
    expect(isOriginAllowed('https://kotu-site.test', allow)).toBe(false);
    // Alt alan adı otomatik güvenilmez.
    expect(isOriginAllowed('https://evil.nocta.app', allow)).toBe(false);
    // Port farkı farklı kaynaktır.
    expect(isOriginAllowed('http://localhost:9999', allow)).toBe(false);
    // Şema farkı farklı kaynaktır.
    expect(isOriginAllowed('https://localhost:3003', allow)).toBe(false);
  });

  it('origin YOKSA izin verir — tarayıcı-dışı istemciler (mobil, curl, sağlık kontrolü)', () => {
    // CORS bir TARAYICI korumasıdır. Origin'siz isteği reddetmek mobil uygulamayı
    // kırardı ve güvenlik kazandırmazdı (curl istediği başlığı gönderebilir).
    expect(isOriginAllowed(undefined, allow)).toBe(true);
  });

  it('boş izin listesi tarayıcıdan gelen HER ŞEYİ reddeder ama mobili kırmaz', () => {
    expect(isOriginAllowed('http://localhost:3003', [])).toBe(false);
    expect(isOriginAllowed(undefined, [])).toBe(true);
  });

  it('gelen kaynaktaki sondaki eğik çizgi karşılaştırmayı bozmaz', () => {
    expect(isOriginAllowed('http://localhost:3003/', allow)).toBe(true);
  });
});
