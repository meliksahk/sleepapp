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

### Color — dark-first. The app lives at night.
- bg/base:        #0A0E1A   (near-black indigo — main app background)
- bg/raised:      #111629   (cards, sheets)
- bg/overlay:     #1A2138   (modals, elevated surfaces)
- ink/primary:    #F2F4FF   (primary text — never pure white)
- ink/secondary:  #9AA3C7   (secondary text)
- ink/faint:      #5A6284   (hints, disabled)
- accent/aurora:  #7C6CFF   (primary brand violet — CTAs, active states)
- accent/dawn:    #FFB489   (warm peach — wake/morning moments, streaks)
- accent/deep:    #2EC5B6   (teal — success, "in session" states)
- danger:         #FF6B7A
- Archetype palette (each sleep identity owns a gradient; use ONLY for
  identity cards, report headers, and archetype accents):
  deep-ocean  #1B3B6F→#0FA3B1 | overthinker #4A2C6F→#7C6CFF
  delta-drifter #0F2E2A→#2EC5B6 | dawn-chaser #6F3A2C→#FFB489
  (extend the same recipe: dark base → luminous tint)
- Light mode exists ONLY for marketing site and admin panel (bg #F7F8FD,
  ink #14182B, same accents). The mobile app is dark-only by design.

### Typography
- Display/headers: "Clash Display" (or geometric humanist fallback: Space
  Grotesk) — used sparingly, large, generous letter-spacing on labels.
- Body/UI: Inter. Numeric data (sleep stats): Inter tabular-nums.
- Scale (mobile): display 34/40, h1 28/34, h2 22/28, body 16/24,
  caption 13/18, micro 11/14. Never below 11.
- Tone of voice in UI copy: warm, second person, short. "Ready when you are."
  not "Initialize sleep session". FORBIDDEN words in any copy: cure, treat,
  therapy, clinically proven, doctor-approved.

### Shape, Space, Depth
- Spacing unit 4px; screen padding 20px; card padding 16–20px.
- Radius: cards 20, sheets 28 (top), buttons 16, chips 12, full-round for
  play controls.
- Elevation via subtle 1px inner borders (#FFFFFF at 6% opacity) + soft glow
  for active audio elements (accent color at 20% blur 24px). No hard drop
  shadows on dark surfaces.
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

### Bu promptun bakımı

- Token değişiklikleri önce `packages/design-tokens/tokens.json`'a girer, sonra bu prompt güncellenir (çift kaynak sapması Dürüstlük Protokolü ihlalidir).
- Yeni imza bileşeni eklendiğinde (ör. widget tasarımı) "Signature Components" bölümüne tek paragraf eklenir.
