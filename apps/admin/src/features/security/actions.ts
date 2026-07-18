'use server';

import { revalidatePath } from 'next/cache';
import { toString as qrToString } from 'qrcode';
import { apiPost } from '@/shared/api/server-client';
import type { MessageKey } from '@/shared/i18n/dictionaries';

/**
 * Hata alanları MESAJ ANAHTARI taşır (dizge değil): eylem sunucuda çalışır, sonuç
 * istemcide gösterilir — dizge metni o anki dile çakardı (bkz. content/actions.ts).
 */
export interface EnrollState {
  error?: MessageKey;
  /** QR'a gömülecek URI — yalnızca kurulum başladığında dolar. */
  otpauthUri?: string;
  /** Elle giriş için base32 anahtar. Yalnızca bu ekranda, bir kez gösterilir. */
  secret?: string;
  /** Hazır SVG — QR SUNUCUDA üretilir, istemciye QR kütüphanesi inmez (JS bütçesi). */
  qrSvg?: string;
}

export interface ConfirmState {
  error?: MessageKey;
  enabled?: boolean;
}

interface EnrollResponse {
  secret: string;
  otpauthUri: string;
}

/**
 * 2FA kurulumunu başlatır (docs/03 A0).
 *
 * Server Action: token httpOnly çerezde olduğu için çağrı SUNUCUDAN geçmek zorunda —
 * tarayıcı API'ye doğrudan gidemez (#116).
 *
 * Anahtar istemciye dönüyor: kaçınılmaz, kullanıcı onu Authenticator'a girmeli
 * (TOTP'nin doğası). Ama yalnızca kimliği doğrulanmış hesap KENDİ anahtarını alır
 * (`sub` token'dan gelir) ve anahtar hiçbir yere LOGLANMAZ.
 */
export async function startEnrollment(): Promise<EnrollState> {
  const res = await apiPost<EnrollResponse>('/v1/auth/admin/totp/enroll', {});

  if (!res.ok) {
    return { error: enrollError(res.status, res.code) };
  }

  return {
    otpauthUri: res.data.otpauthUri,
    secret: res.data.secret,
    qrSvg: await qrSvg(res.data.otpauthUri),
  };
}

/**
 * otpauth URI → SVG. Sunucuda üretilir: istemciye QR kütüphanesi indirmek, yılda
 * birkaç kez açılan bir ekran için her ziyaretçiye JS yüklemek olurdu.
 *
 * Hata durumunda undefined döner, ÇÖKMEZ: QR üretilemese de anahtar elle
 * girilebilir — kurulumu tümden engellemek orantısız olurdu.
 */
async function qrSvg(uri: string): Promise<string | undefined> {
  try {
    return await qrToString(uri, { type: 'svg', margin: 1, errorCorrectionLevel: 'M' });
  } catch {
    return undefined;
  }
}

/**
 * İlk geçerli kodla 2FA'yı etkinleştirir.
 *
 * `useActionState` imzası: (öncekiDurum, formData). Önceki durum KULLANILMAZ ama
 * imzada durmalı — React onu böyle çağırır.
 */
export async function confirmEnrollment(
  _previous: ConfirmState,
  formData: FormData,
): Promise<ConfirmState> {
  const code = String(formData.get('code') ?? '');

  // Sunucuda da doğrulanır: istemci kontrolü atlanabilir (curl, devre dışı JS).
  if (!/^\d{6}$/.test(code)) {
    return { error: 'security.errorCodeFormat' };
  }

  const res = await apiPost<undefined>('/v1/auth/admin/totp/confirm', { code });
  if (!res.ok) {
    return { error: confirmError(res.status, res.code) };
  }

  // Sayfa "2FA etkin" rozetini SUNUCUDAN okur; önbellek tazelenmezse kullanıcı
  // etkinleştirdiği hâlde "kapalı" görürdü.
  revalidatePath('/security');
  return { enabled: true };
}

export interface ResetState {
  error?: MessageKey;
  /** 2FA kaldırıldı → kullanıcı yeniden kurabilir (cihaz rotasyonu). */
  done?: boolean;
}

/**
 * 2FA'yı PAROLA doğrulamasıyla sıfırlar (#186 API'si) — yeni cihaza geçmek için. Parola
 * olmadan sıfırlama, oturumu ele geçirenin 2FA'yı devralmasına izin verirdi; bu yüzden
 * parola zorunlu (doğrulama sunucuda). Sıfırlama sonrası kullanıcı baştan kurabilir.
 */
export async function resetTotp(_previous: ResetState, formData: FormData): Promise<ResetState> {
  const password = String(formData.get('password') ?? '');
  // Sunucuda da doğrulanır (boş parola 400); burada erken geri bildirim.
  if (password.length === 0) {
    return { error: 'security.errorPasswordRequired' };
  }

  const res = await apiPost<undefined>('/v1/auth/admin/totp/reset', { password });
  if (!res.ok) {
    return { error: resetError(res.status, res.code) };
  }

  // 2FA kalktı → rozet + kurulum ekranı SUNUCUDAN yeniden okunmalı.
  revalidatePath('/security');
  return { done: true };
}

function enrollError(status: number, code?: string): MessageKey {
  if (code === 'totp_already_enabled') {
    // Bilinçli 409: onaylı 2FA'nın üstüne yazmak, oturumu ele geçirenin 2FA'yı
    // kendi cihazına taşımasına izin verirdi.
    return 'security.errorAlreadyEnabled';
  }
  if (status === 401) return 'security.errorSession';
  if (status === 429) return 'security.errorRate';
  return 'security.errorEnrollGeneric';
}

function resetError(status: number, code?: string): MessageKey {
  // Reset ucunda 401: parola hatası (invalid_credentials) VEYA oturum bitti — code ayırır.
  if (code === 'invalid_credentials') return 'security.errorInvalidPassword';
  if (status === 401) return 'security.errorSession';
  if (status === 429) return 'security.errorRate';
  return 'security.errorResetGeneric';
}

function confirmError(status: number, code?: string): MessageKey {
  if (code === 'totp_already_enabled') return 'security.errorAlreadyEnabledShort';
  // 401 burada "oturum bitti" değil "kod tutmadı" demek: uç kimlik doğrulamalı ve
  // buraya ancak geçerli oturumla gelinir.
  if (status === 401) return 'security.errorCodeInvalid';
  if (status === 429) return 'security.errorRate';
  return 'security.errorConfirmGeneric';
}
