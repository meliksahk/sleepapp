# Analitik Olay Sözlüğü

> **Kural (docs/01 §7):** Sözlükte olmayan event **gönderilemez**. API ingest
> (`POST /v1/analytics/events`) bilinmeyen adı `unknown_event` ile **reddeder**.

## Nasıl yeni olay eklenir

1. Bu tabloya satır ekle (ad, ne zaman, props, yüzey).
2. `apps/api/src/modules/analytics/domain/analytics-event.ts` → `KNOWN_EVENT_NAMES` setine ekle
   (kod tarafındaki tek kaynak; bu doküman onunla senkron tutulur).
3. Ancak bundan sonra istemci o olayı gönderebilir.

Sıra önemlidir: sözlük önce, gönderim sonra. Aksi halde batch 400 döner.

## Ad kuralları

- Biçim: `^[a-z0-9_.]{1,64}$` (küçük harf, rakam, `_`, `.`).
- Geçmiş zaman, nesne_fiil: `archetype_completed`, `share_tapped`.
- **PII YASAK** (CLAUDE.md §6): `props` içinde e-posta, ham metin, ham mikrofon
  verisi veya kullanıcıyı tanımlayan alan taşınmaz. Yalnızca türetilmiş/kategorik
  değerler (ör. `archetype: 'deep-ocean'`). Kullanıcı kimliği zaten token'dan gelir.

## Olaylar

| Olay                  | Ne zaman                                 | props              | Yüzey |
| --------------------- | ---------------------------------------- | ------------------ | ----- |
| `archetype_completed` | Archetype testi tamamlanıp sonuç görünce | `archetype` (slug) | mobil |
| `share_tapped`        | Archetype kartı başarıyla paylaşılınca   | `archetype` (slug) | mobil |

> Tabloda yalnızca **gerçekten yayılan** olaylar bulunur (spekülatif olay eklenmez).
> Ses motoru, uyku takibi ve mix-to-video olayları o özellikler geldiğinde eklenecek.

## Notlar

- İngest **batch** alır; tek olay bile geçersiz/bilinmeyense **tüm batch** 400 döner
  (kısmi kabul yok — veri kalitesi ve istemci hatasının erken görünmesi için).
  Bunun sonucu: istemci sözlükten önce olay eklerse o batch kaybolur → sıra kuralı.
- Kabul edilen olaylar `202 Accepted` + `{accepted: n}` döner.
- Tek istekte azami `MAX_EVENTS_PER_BATCH` (100) olay.
