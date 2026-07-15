<!-- CLAUDE.md §4 PR kuralı: küçük PR (<400 satır), "ne + neden + nasıl test edildi". -->

## Ne

<!-- Bu PR ne yapıyor? -->

## Neden

<!-- Hangi faz işi / hangi ihtiyaç? İlgili docs/0X veya LOOP_STATE. -->

## Nasıl test edildi

<!-- Komut çıktısı / test sonucu / ekran görüntüsü. Kanıtsız "çalışıyor" yasak. -->

---

## DURUM RAPORU

<!-- Dürüstlük Protokolü (CLAUDE.md §0) — blok boş geçilemez. -->

```
✅ Yapıldı ve doğrulandı :
⚠️ Yapıldı, doğrulanmadı :
❌ Yapılmadı / eksik      :
📌 Varsayımlar            :
🔥 Riskler / açıklar      :
```

## Definition of Done (CLAUDE.md §7)

- [ ] Mimari kurallara uygun (boundary lint'ler yeşil)
- [ ] Testler yazıldı ve geçiyor; CI yeşil
- [ ] i18n / erişilebilirlik (touch ≥44px, kontrast AA) / dark-mode kontrol edildi
- [ ] Sağlık iddiası taraması yapıldı (metin değiştiyse)
- [ ] Kişisel-veri ucu varsa "A, B'nin verisini okuyamaz" testi eklendi
- [ ] docs/ etkilendiyse güncellendi
