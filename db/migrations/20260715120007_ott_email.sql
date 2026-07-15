-- migrate:up

-- Magic link OTT'si için hedef e-posta (doğrulamada user'a uygulanır). Nullable —
-- email_verify/password_reset purpose'larında kullanılmayabilir.
ALTER TABLE one_time_tokens ADD COLUMN email text;

-- migrate:down

ALTER TABLE one_time_tokens DROP COLUMN IF EXISTS email;
