# 06 — Claude Design Master Promptu

> Kullanım: Bu promptun tamamını Claude'a (design oturumu / Claude Design / herhangi bir UI üretim aracı) her tasarım görevinin başında ver. Ardından tek satır görev ekle: "Bu sisteme uygun olarak X ekranını tasarla." Prompt İngilizce tutuldu çünkü tasarım araçları İngilizce promptla daha tutarlı sonuç veriyor; TR çevirisi gereken yerde bölüm sonundaki notu kullan.

---

```
# NOCTA Design System — Master Prompt

You are designing for NOCTA, a sleep-ritual app built around "sleep identity".
Surfaces: iOS/Android app (Flutter), admin panel, marketing website. Everything
you produce must feel like ONE product across all three.

## Brand Essence
- One line: "Your night has an identity."
- Personality: calm, intimate, quietly premium, a little mystical — like a
  planetarium, not a hospital. Never clinical, never childish, never "wellness
  guru" cliché (no lotus flowers, no meditation silhouettes, no zen stones).
- The product is honest by principle: no fake science aesthetics (no fake EEG
  waves, no "clinically proven" badges). Visual language may evoke frequency,
  resonance, night sky, depth of water — abstract, not pseudo-medical.

## Core Design Tokens (single source of truth — never invent new hex values)

### Color — "Elegy" collage. Dark-first; the app lives at night.
Warm near-black canvas + torn cream paper + one Motherwell red. Not indigo,
not neon. Every value below is generated from `packages/design-tokens/tokens.json`.
- bg/base:        #08080A   (night canvas — main app background)
- bg/raised:      #0E0D0C   (panels, layer cards)
- bg/overlay:     #131210   (sheets, hover, skeletons)
- bg/paper:       #E9E2D4   (TORN PAPER surface — the founding element)
- ink/primary:    #E9E2D4   (primary text, warm cream — never pure white)
- ink/secondary:  #A49E92
- ink/faint:      #8E877C   (mono micro-labels — AA at 5.9:1)
- ink/mute:       #6B655C   (NON-TEXT only: rules, ticks, dividers — 3.4:1)
- ink/onPaper:    #14140F   (text on bg/paper)  · ink/onPaperSoft: #57544A
- line/hairline #1C1A17 · soft #26241F · strong #3A362F · dashed #33302A
- accent/aurora:  #C1442E   (the red — fills, marks, active bars. NOT small text)
- accent/auroraInk: #E0765F (accent TEXT on dark — AA)
- accent/dawn:    #B98A34   (amber — wake, timer, streak)
- accent/deep:    #8A8F7A   (sage — success, "in session")
- danger:         #C1442E   (same family; danger surface #170F0D, border #7A4038)
- Archetype: identity is carried by a GENERATIVE CONSTELLATION pattern (seeded
  per archetype), not by hue. Each still owns a dark base → tint pair so the
  four never render identically.
- Light mode exists ONLY for marketing site and admin panel (bg #F3EFE6,
  ink #14140F). The mobile app is dark-only by design.

### Typography — three voices
- Display/headers: **Instrument Serif** — large, quiet, never bold.
- Micro-labels: **IBM Plex Mono**, uppercase, wide tracking (1–3px). This is
  the system's signature; section labels, meta rows, button labels are mono.
- Body/UI: Inter. Numeric data (sleep stats): Inter tabular-nums.
- Scale (mobile): display 42/44, h1 33/38, h2 26/29, body 15/24,
  caption 13/20, micro 11/16. Never below 11 — the source design proposed
  9–10px mono labels; 11 is the accessibility floor and it wins.
- NEVER call `toUpperCase()` in code: Dart's locale-free mapping gives Turkish
  `i → I` (must be `İ`). Uppercase belongs in the i18n string.
- Tone of voice in UI copy: warm, second person, short. "Ready when you are."
  not "Initialize sleep session". FORBIDDEN words in any copy: cure, treat,
  therapy, clinically proven, doctor-approved.

### Shape, Space, Depth
- Spacing unit 4px; screen padding 24px; card padding 16–20px.
- **Radius 0.** Cards, buttons and chips are rectangles; the only curves are
  the sheet's top (28) and true circles (play control, organic blobs).
- Edges are either sharp-cut or TORN (`NPaper` — deterministic jagged clip).
- Depth comes from 1px lines and the paper/canvas contrast, never from shadow.
- A fine static grain sits on paper surfaces (`NGrain`). It does not animate:
  full-screen animated noise costs battery all night for no meaning.
- Iconography: 1.5px stroke, rounded caps (Lucide style), never filled except
  active tab.

### Motion
- Everything breathes: idle animations at 6–8s cycles (slow pulse on the
  session orb), transitions 250–350ms ease-out. Nothing bounces. Nothing
  flashes. Respect prefers-reduced-motion.
- Audio-reactive elements (mixer, video export visuals) use slow fluid forms:
  perlin-noise blobs, waveform ribbons — organic, not spiky EQ bars.

## Signature Components (reuse these patterns everywhere)
1. Identity Card: 1080×1920 and 1:1 variants. Archetype gradient background,
   large archetype name in Display font, constellation-like generative pattern
   unique to the archetype, small NOCTA wordmark bottom-right. Must be
   beautiful enough that sharing it feels like showing off, not advertising.
2. Night Receipt (sleep report): looks like a premium receipt/ticket —
   monospaced-adjacent stat rows, sparkline of the night, one warm insight
   sentence, perforated-edge visual metaphor, archetype accent. Screenshot-bait
   by design.
3. Session Orb: the central "start sleep" control — a slowly breathing
   gradient sphere. The whole sleep screen is built around it, minimal
   everything else, brightness floor (no element brighter than 40% luminance
   at night).
4. Mixer Layers: horizontal cards with big (min 44px) touch targets,
   one-hand reachable, glow intensity = volume.

## Per-Surface Rules
- Mobile app: dark-only, one primary action per screen, bottom-reachable
  controls, night screens must pass "3AM squint test" (usable half-asleep).
- Admin panel: light-first, dense but calm; shadcn/ui components skinned with
  the same tokens; data tables and charts use ink/secondary grid, accent only
  for the single most important series.
- Marketing site: light with night-gradient hero sections; generous white
  space; every page ends with the archetype test CTA, not a download button.

## Accessibility (non-negotiable)
- Contrast AA minimum on all text (check accents on dark backgrounds).
- Touch targets ≥44px. Full VoiceOver labels on interactive elements.
- Never rely on color alone for state; pair with icon/label.

## Output Requirements
When you produce a design: state which tokens you used; flag any place you
needed something the system doesn't define (propose an addition, don't
silently invent); provide both the happy state and empty/error/loading states
for any data-driven screen.
```

---

### Not — TR kullanım

Prompt'taki marka/eser isimleri (NOCTA, archetype adları) çalışma adlarıdır; isim netleşince tek yerden değiştir. UI metin örnekleri EN'dir; TR yerelleştirmede ton kuralı aynen geçer: sıcak, ikinci tekil, kısa ("Hazır olduğunda başlayalım").

### Elegy'nin uygulanma durumu (2 Ağu 2026)

Sistem `packages/design-tokens/tokens.json` → `NoctaColors/NoctaFont/NoctaTrack/...`
üzerinden **var olan 15 ekranın tamamına** uygulandı. Ortak bileşenler:
`NPaper` (yırtık kağıt + tanecik), `NGrain`, `NMono`, `NDisplay`, `NEmptyState`,
`NightReceipt` (gece makbuzu — ekran ve paylaşım kartı aynı anatomiyi kullanır).

**Uygulanmayan üç kural ve gerekçesi** (tasarımdan bilinçli sapma):

1. Mono mikro etiketler `#6B655C` / 9–10px önerilmişti → `#8E877C` / 11px
   (3.4:1 → 5.9:1; AA ve 11px tabanı kazanır). `ink.mute` metin için kullanılmaz.
2. Kızıl üstü küçük metin → `accent.auroraInk` (#E0765F) eklendi.
3. Tanecik animasyonu → statik (gece boyunca açık ekranda pil bütçesi).

**Uyku modu ekranı AA'nın dışındadır** (`color.night.*`): kullanıcı uyumak üzere,
ekran ışık kaynağı olmamalı. Bu istisna yalnızca o ekranda geçerlidir.

**Henüz ÜRETİLMEMİŞ ekranlar** (tasarımda var, uygulamada yok — ürün işi, cila değil):
mikrofon izin gerekçesi, akıllı alarm kurulumu, hesap silme, Share Studio,
preset yönetimi, katman detayı, ritüel/seri ekranı, bildirim ayarları.

### Bu promptun bakımı

- Token değişiklikleri önce `packages/design-tokens/tokens.json`'a girer, sonra bu prompt güncellenir (çift kaynak sapması Dürüstlük Protokolü ihlalidir).
- Yeni imza bileşeni eklendiğinde (ör. widget tasarımı) "Signature Components" bölümüne tek paragraf eklenir.
