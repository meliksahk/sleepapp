'use client';

import { useEffect, useRef, useState } from 'react';
import { CARD_HEIGHT, CARD_WIDTH, cardFileName, wrapText } from '@/lib/share-card';
import { t, type Locale } from '@/lib/i18n';
import { localePath } from '@/lib/routes';

/**
 * Archetype sonucunun İNDİRİLEBİLİR paylaşım kartı (docs/05 viral kanca). Client-side
 * canvas ile 9:16 (IG story) görsel üretir; kullanıcı kaydeder/paylaşır. Renkler tasarım
 * tokenlarından (`getComputedStyle`) okunur — hex hard-code YOK (CLAUDE.md §2), her
 * archetype kendi gradyanını alır.
 *
 * Sağlık iddiası yok (§1.1): yalnızca kimlik adı + tagline + "sana uyan sesler".
 */
export function ShareCard({
  slug,
  name,
  tagline,
  sounds,
  locale = 'en',
}: {
  slug: string;
  name: string;
  tagline: string;
  sounds: readonly string[];
  locale?: Locale;
}) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState<string | null>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    // Canvas ortamda yoksa (SSR/jsdom test) çizim atlanır ama sayfa/test ÇÖKMEZ.
    // Try/catch tüm çizimi sarar: bir ctx metodu desteklenmese bile kart sessizce boş kalır.
    try {
      draw(canvas);
    } catch {
      // no-op: kart çizilemedi (canvas yok) — ama sonuç ekranı yaşamaya devam eder.
    }
    // `locale` de bağımlılık: kart üzerindeki metin dile göre değişir (yoksa TR
    // sayfada kart İngilizce çizilirdi).
  }, [slug, name, tagline, sounds, locale]);

  function draw(canvas: HTMLCanvasElement): void {
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const root = getComputedStyle(document.documentElement);
    const token = (n: string, fallback: string) => {
      const v = root.getPropertyValue(n).trim();
      return v.length > 0 ? v : fallback;
    };
    const from = token(`--color-archetype-${slug}-from`, '#1B3B6F');
    const to = token(`--color-archetype-${slug}-to`, '#7C6CFF');
    const ink = token('--color-ink-primary', '#F2F4FF');
    const inkDim = token('--color-ink-secondary', '#9AA3C7');

    const pad = 96;
    const maxTextWidth = CARD_WIDTH - pad * 2;

    // Arka plan: archetype gradyanı (köşegen) + altta okunabilirlik için koyu geçiş.
    const bg = ctx.createLinearGradient(0, 0, CARD_WIDTH, CARD_HEIGHT);
    bg.addColorStop(0, from);
    bg.addColorStop(1, to);
    ctx.fillStyle = bg;
    ctx.fillRect(0, 0, CARD_WIDTH, CARD_HEIGHT);

    const shade = ctx.createLinearGradient(0, CARD_HEIGHT * 0.35, 0, CARD_HEIGHT);
    shade.addColorStop(0, 'rgba(10,14,26,0)');
    shade.addColorStop(1, 'rgba(10,14,26,0.72)');
    ctx.fillStyle = shade;
    ctx.fillRect(0, 0, CARD_WIDTH, CARD_HEIGHT);

    ctx.textBaseline = 'alphabetic';

    // Üst etiket
    try {
      ctx.letterSpacing = '8px';
    } catch {
      // eski tarayıcı → letterSpacing yok; sorun değil.
    }
    ctx.fillStyle = inkDim;
    ctx.font = "600 34px 'Segoe UI', system-ui, -apple-system, sans-serif";
    ctx.fillText(t(locale, 'card.eyebrow'), pad, 200);
    try {
      ctx.letterSpacing = '0px';
    } catch {
      /* no-op */
    }

    // Archetype adı (büyük, sarılı)
    ctx.fillStyle = ink;
    const nameSize = 132;
    ctx.font = `700 ${nameSize}px 'Segoe UI', system-ui, -apple-system, sans-serif`;
    const nameLines = wrapText(name, maxTextWidth, (s) => ctx.measureText(s).width);
    let y = 360;
    for (const line of nameLines) {
      ctx.fillText(line, pad, y);
      y += nameSize * 1.05;
    }

    // Tagline
    ctx.fillStyle = inkDim;
    const tagSize = 46;
    ctx.font = `400 ${tagSize}px 'Segoe UI', system-ui, -apple-system, sans-serif`;
    y += 24;
    for (const line of wrapText(tagline, maxTextWidth, (s) => ctx.measureText(s).width)) {
      ctx.fillText(line, pad, y);
      y += tagSize * 1.3;
    }

    // "Sounds that suit you" — alt üçlük
    const soundsTop = CARD_HEIGHT - 560;
    ctx.fillStyle = ink;
    ctx.font = "600 40px 'Segoe UI', system-ui, -apple-system, sans-serif";
    ctx.fillText(t(locale, 'card.soundsHeading'), pad, soundsTop);
    ctx.fillStyle = inkDim;
    ctx.font = "400 42px 'Segoe UI', system-ui, -apple-system, sans-serif";
    sounds.slice(0, 3).forEach((s, i) => {
      ctx.fillText(`•  ${s}`, pad, soundsTop + 76 + i * 66);
    });

    // Alt filigran: marka + URL
    ctx.fillStyle = ink;
    ctx.font = "700 52px 'Segoe UI', system-ui, -apple-system, sans-serif";
    ctx.fillText('NOCTA', pad, CARD_HEIGHT - 110);
    ctx.fillStyle = inkDim;
    ctx.font = "400 36px 'Segoe UI', system-ui, -apple-system, sans-serif";
    // Filigrandaki URL dil sürümünü gösterir; slug ÇEVRİLMEZ (paylaşım linkleri sabit).
    ctx.fillText(`nocta.app${localePath(locale, `/a/${slug}`)}`, pad, CARD_HEIGHT - 60);
  }

  async function onSave(): Promise<void> {
    const canvas = canvasRef.current;
    if (!canvas || busy) return;
    setBusy(true);
    setStatus(null);
    try {
      const blob = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, 'image/png'));
      if (!blob) {
        setStatus(t(locale, 'card.error'));
        return;
      }
      const fileName = cardFileName(slug);
      const file = new File([blob], fileName, { type: 'image/png' });
      const nav = navigator as Navigator & {
        canShare?: (d: ShareData) => boolean;
        share?: (d: ShareData) => Promise<void>;
      };
      // Mobil: görseli doğrudan paylaş (IG/mesaj). Masaüstü/desteksiz: indir.
      if (nav.canShare?.({ files: [file] }) && typeof nav.share === 'function') {
        const shared = await nav
          .share({ files: [file], title: t(locale, 'card.shareTitle', { name }) })
          .then(
            () => true,
            () => false,
          );
        if (shared) return;
      }
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = fileName;
      a.click();
      URL.revokeObjectURL(url);
      setStatus(t(locale, 'card.saved'));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="flex flex-col items-start gap-3">
      <canvas
        ref={canvasRef}
        width={CARD_WIDTH}
        height={CARD_HEIGHT}
        aria-label={t(locale, 'card.previewAlt', { name })}
        className="w-full max-w-[280px] rounded-card border border-ink-faint/20"
        style={{ height: 'auto' }}
      />
      <button
        type="button"
        onClick={onSave}
        disabled={busy}
        className="rounded-button bg-accent-aurora px-5 py-3 text-bg-base disabled:opacity-60"
      >
        {busy ? t(locale, 'card.preparing') : t(locale, 'card.save')}
      </button>
      {status !== null && (
        <p role="status" className="text-caption text-ink-secondary">
          {status}
        </p>
      )}
    </div>
  );
}
