# DECISIONS_NEEDED — insandan karar bekleyen konular

> Loop öznel/geri-alınması pahalı kararları buraya yazar ve en makul varsayımla
> ilerler (LOOP.md). Cevap gelince ilgili yer güncellenir.

## Açık kararlar

### D-1 · Repo görünürlüğü vs. branch protection (öncelikli)

- **Durum:** GitHub free planda private repoda branch protection/ruleset API'si kapalı (BLOCKERS B-4).
- **Seçenekler:**
  1. **Private kal, disiplinle devam** (varsayılan — şu an bu): koruma platformda zorlanmaz, PR akışı elle sürdürülür. Maliyet 0.
  2. **Repoyu public yap:** branch protection ücretsiz açılır; ama kod herkese açık olur (erişim-kontrolü kararı — sormadan yapılmaz).
  3. **GitHub Pro:** ~4$/ay; kickoff "ücretli servis açma" kuralına takılır.
- **Varsayım (şimdilik):** Seçenek 1. Değiştirmek istersen söyle.

### D-2 · Sentry DSN

- **Durum:** API'de Sentry env-opsiyonel bırakıldı (`SENTRY_DSN` boşsa devre dışı). Kod entegrasyonu F1'de eklenecek.
- **Gerekli:** dört proje (mobile/api/admin/web) için Sentry DSN'leri (free tier). Verince `.env`/GitHub Environments'a konur (repoya değil).

### D-3 · VPS kimlik bilgileri (docs/09 Adım 2 & 5)

- **Durum:** "Önce lokal" kararıyla ertelendi.
- **Gerekli (sıra gelince):** Hostinger VPS IP + SSH kullanıcısı (+ staging subdomain, opsiyonel). Koda/repoya ASLA yazılmaz; SSH key-only erişim, ufw, fail2ban, docker, compose stack, GitHub Actions SSH deploy kurulacak.

### D-5 · SMTP sağlayıcı (magic link e-posta gönderimi)

- **Durum:** Magic link e-posta yükseltme kodu tamam; şu an **log-mailer** (linki loglar, gerçek e-posta göndermez). Gerçek gönderim için SMTP sağlayıcı gerekiyor (self-host mail deliverability nedeniyle yasak, docs/02 §3).
- **Gerekli:** Brevo veya Resend free tier API anahtarı → `shared/infra/mailer` adaptörü tek satırla gerçek sağlayıcıya geçer.
- **Varsayım (şimdilik):** log-mailer ile devam; dev/test raw token'ı response'ta döner (prod'da gizli).

### D-4 · Ürün/ton kararları (düşük öncelik, varsayımla ilerleniyor)

- Marka adı **NOCTA** çalışma kod adı (docs/06) — netleşince token/isim tek yerden değişir.
- Archetype slug'ları (deep-ocean/overthinker/delta-drifter/dawn-chaser) taslak.
- Fiyatlandırma/paywall: F6'ya (docs/10) ertelendi.
