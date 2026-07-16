-- migrate:up

-- Admin TOTP 2FA durumu (CLAUDE.md §3.3). `totp_secret` init'te vardı ama TEK BAŞINA
-- yetmiyor: iki kolon daha olmadan 2FA ya güvensiz ya da kurulamaz olurdu.

-- NEDEN: gizli anahtar üretildiği AN'da 2FA'yı zorunlu kılarsak, kullanıcı kodu
-- Authenticator'a girmeden önce (ya da yanlış girip) kendini KALICI OLARAK kilitler —
-- parola doğru, ama asla üretemeyeceği bir kod isteniyor. Bu yüzden akış iki adım:
-- kur (secret yazılır, 2FA HENÜZ ZORUNLU DEĞİL) → doğrula (ilk geçerli kodla onaylanır).
-- Zorunluluk YALNIZCA bu damga doluysa başlar. NULL = kurulum yarıda kalmış, giriş
-- eskisi gibi çalışır.
ALTER TABLE users ADD COLUMN totp_confirmed_at timestamptz;

-- NEDEN: RFC 6238 §5.2 aynı kodun İKİ KEZ kabul edilmesini YASAKLAR. Kod 30 sn
-- geçerlidir; omuz üstünden ya da ekran paylaşımından kodu gören biri, bu kolon
-- olmadan aynı kodla ikinci kez girebilirdi — 2FA'nın koruduğu şeyin tam ortasından.
-- Son kabul edilen sayaç saklanır; o ve daha eskisi bir daha kabul edilmez.
--
-- bigint: sayaç = unix_seconds/30. int32 2038'de değil, ~2106'da taşardı; yine de
-- taşma ihtimali olan bir alanı 4 bayt için riske atmanın hiçbir kazancı yok.
ALTER TABLE users ADD COLUMN totp_last_counter bigint;

-- migrate:down

ALTER TABLE users DROP COLUMN IF EXISTS totp_last_counter;
ALTER TABLE users DROP COLUMN IF EXISTS totp_confirmed_at;
