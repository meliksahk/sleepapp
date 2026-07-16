import { Injectable, type NestMiddleware } from '@nestjs/common';
import type { NextFunction, Request, Response } from 'express';

/**
 * Güvenlik başlıkları (docs/02 B4 sertleşme) — harici bağımlılık YOK (helmet
 * gerekmez; JSON API'ye uygun minimal set). MIDDLEWARE olduğu için guard'lardan
 * ÖNCE çalışır → 401/403 dahil TÜM yanıtlara uygulanır.
 *
 * - X-Content-Type-Options: nosniff → MIME-sniffing kapatılır.
 * - X-Frame-Options: DENY → API yanıtı frame'lenemez (clickjacking yüzeyi yok).
 * - Referrer-Policy: no-referrer → istek URL'leri referer ile sızmaz.
 * - Cross-Origin-Resource-Policy: same-origin → kaynak çapraz-köken gömülemez.
 * Not: X-Powered-By main.ts'te app düzeyinde kapatılır (framework parmak izi).
 */
@Injectable()
export class SecurityHeadersMiddleware implements NestMiddleware {
  use(_req: Request, res: Response, next: NextFunction): void {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('X-Frame-Options', 'DENY');
    res.setHeader('Referrer-Policy', 'no-referrer');
    res.setHeader('Cross-Origin-Resource-Policy', 'same-origin');
    next();
  }
}
