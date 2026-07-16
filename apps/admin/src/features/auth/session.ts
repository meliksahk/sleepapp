/**
 * Panel oturum çerezleri (docs/03 A0).
 *
 * NEDEN httpOnly ÇEREZ, NEDEN localStorage DEĞİL: panelde token localStorage'da
 * dursa, herhangi bir XSS (bir bağımlılık, bir içerik alanı) admin token'ını
 * okuyabilirdi — sistemdeki en yetkili anahtar. httpOnly çerez JS'ten okunamaz;
 * token yalnızca sunucu tarafında (route handler / middleware) görülür.
 *
 * Bedeli: tarayıcı API'ye doğrudan gidemez, panelin kendi route handler'ı üzerinden
 * geçer. Bu bedeli bilerek ödüyoruz.
 */
export const ACCESS_COOKIE = 'nocta_admin_at';
export const REFRESH_COOKIE = 'nocta_admin_rt';

/** Çerez ortak ayarları. `secure` yalnızca production'da: lokal http://localhost'ta
 *  secure çerez tarayıcıya hiç yazılmaz ve giriş sessizce çalışmaz görünürdü. */
export function cookieOptions(maxAge: number): {
  httpOnly: true;
  sameSite: 'lax';
  secure: boolean;
  path: string;
  maxAge: number;
} {
  return {
    httpOnly: true,
    // 'lax': panel kendi origin'ine POST atar; 'strict' girişten sonra ilk
    // yönlendirmede çerezi göndermeyip sonsuz login döngüsü üretebilir.
    sameSite: 'lax',
    secure: process.env.NODE_ENV === 'production',
    path: '/',
    maxAge,
  };
}
