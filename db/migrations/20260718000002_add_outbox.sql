-- migrate:up

-- Transactional outbox (CLAUDE.md §3.2: "Domain event'ler outbox pattern ile güvenilir
-- yayınlanır"). Amaç: ikili-yazma (dual-write) sorununu çözmek. Bir domain yazısı (ör. uyku
-- oturumu kaydı) yan-etki (push bildirimi) tetiklemeli; ama önce DB'ye yaz sonra kuyruğa
-- gönder yaparsak, ikisi arasında süreç çökerse olay KAYBOLUR. Outbox: olay, domain yazısıyla
-- AYNI transaction'da bu tabloya yazılır (atomik) → bir relay sonra yayınlar. Süreç çökse de
-- olay tabloda durur, relay bir dahaki turda yayınlar.
CREATE TABLE outbox (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  aggregate_type text        NOT NULL,        -- ör. 'sleep_session'
  event_type     text        NOT NULL,        -- ör. 'sleep.session_recorded'
  payload        jsonb       NOT NULL,        -- olay verisi (ham PII taşımaz — §6)
  created_at     timestamptz NOT NULL DEFAULT now(),
  published_at   timestamptz                  -- NULL = yayınlanmamış; relay bunları çeker
);

-- Relay yalnızca YAYINLANMAMIŞ satırları en eskiden yeniye tarar. Kısmi index: published_at
-- dolunca satır index'ten düşer → index yalnızca "yapılacak iş" kadar büyür (yayınlanmış
-- milyonlarca olay index'i şişirmez).
CREATE INDEX idx_outbox_unpublished ON outbox (created_at) WHERE published_at IS NULL;

-- migrate:down

DROP TABLE IF EXISTS outbox;
