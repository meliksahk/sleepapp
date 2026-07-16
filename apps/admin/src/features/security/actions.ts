'use server';

import { revalidatePath } from 'next/cache';
import { toString as qrToString } from 'qrcode';
import { apiPost } from '@/shared/api/server-client';

export interface EnrollState {
  error?: string;
  /** QR'a gömülecek URI — yalnızca kurulum başladığında dolar. */
  otpauthUri?: string;
  /** Elle giriş için base32 anahtar. Yalnızca bu ekranda, bir kez gösterilir. */
  secret?: string;
  /** Hazır SVG — QR SUNUCUDA üretilir, istemciye QR kütüphanesi inmez (JS bütçesi). */
  qrSvg?: string;
}

export interface ConfirmState {
  error?: string;
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
    return { error: 'Kod 6 haneli olmalı.' };
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

function enrollError(status: number, code?: string): string {
  if (code === 'totp_already_enabled') {
    // Bilinçli 409: onaylı 2FA'nın üstüne yazmak, oturumu ele geçirenin 2FA'yı
    // kendi cihazına taşımasına izin verirdi.
    return 'Bu hesapta iki adımlı doğrulama zaten etkin.';
  }
  if (status === 401) return 'Oturumunuz sona ermiş. Yeniden giriş yapın.';
  if (status === 429) return 'Çok fazla deneme yapıldı. Bir dakika bekleyin.';
  return 'Kurulum başlatılamadı. Lütfen tekrar deneyin.';
}

function confirmError(status: number, code?: string): string {
  if (code === 'totp_already_enabled') return 'İki adımlı doğrulama zaten etkin.';
  // 401 burada "oturum bitti" değil "kod tutmadı" demek: uç kimlik doğrulamalı ve
  // buraya ancak geçerli oturumla gelinir.
  if (status === 401) return 'Kod hatalı veya süresi doldu. Uygulamadaki yeni kodu girin.';
  if (status === 429) return 'Çok fazla deneme yapıldı. Bir dakika bekleyin.';
  return 'Kod doğrulanamadı. Lütfen tekrar deneyin.';
}
