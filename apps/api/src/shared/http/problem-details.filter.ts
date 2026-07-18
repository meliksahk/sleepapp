import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import * as Sentry from '@sentry/node';
import type { Response } from 'express';

interface ProblemDetails {
  type: string;
  title: string;
  status: number;
  detail?: string;
  /** Domain hata kodu (ör. refresh_token_reuse) — istemci dallanması için. */
  code?: string;
}

/** http-errors tarzı hata (statusCode + expose taşır); body-parser bunları fırlatır. */
interface HttpErrorLike {
  statusCode?: number;
  status?: number;
  expose?: boolean;
  message?: string;
}

function isHttpError(e: unknown): e is HttpErrorLike {
  if (typeof e !== 'object' || e === null) return false;
  const r = e as HttpErrorLike;
  const s = typeof r.statusCode === 'number' ? r.statusCode : r.status;
  return typeof s === 'number' && s >= 400 && s <= 599;
}

const TITLES: Record<number, string> = {
  400: 'Bad Request',
  401: 'Unauthorized',
  403: 'Forbidden',
  404: 'Not Found',
  409: 'Conflict',
  413: 'Payload Too Large',
  429: 'Too Many Requests',
  500: 'Internal Server Error',
  503: 'Service Unavailable',
};

/**
 * Tüm hataları RFC 7807 problem+json'a çevirir (docs/02 §4). Controller'ların
 * fırlattığı { code, message } korunur; kullanıcıya mesaj / loglanan teknik ayrım.
 */
@Catch()
export class ProblemDetailsFilter implements ExceptionFilter {
  private readonly logger = new Logger('Http');

  catch(exception: unknown, host: ArgumentsHost): void {
    const res = host.switchToHttp().getResponse<Response>();
    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let detail: string | undefined;
    let code: string | undefined;

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const response = exception.getResponse();
      if (typeof response === 'string') {
        detail = response;
      } else if (typeof response === 'object' && response !== null) {
        const r = response as Record<string, unknown>;
        code = typeof r.code === 'string' ? r.code : undefined;
        if (typeof r.message === 'string') {
          detail = r.message;
        } else if (Array.isArray(r.message)) {
          detail = r.message.join('; ');
        }
      }
    } else if (isHttpError(exception)) {
      // http-errors tarzı (ör. body-parser PayloadTooLargeError 413) — HttpException değil.
      status = exception.statusCode ?? exception.status ?? HttpStatus.INTERNAL_SERVER_ERROR;
      if (exception.expose === true && typeof exception.message === 'string') {
        detail = exception.message;
      }
    } else {
      // Beklenmeyen hata — teknik detay loglanır, istemciye sızmaz.
      this.logger.error(exception instanceof Error ? exception.stack : String(exception));
    }

    // 5xx = beklenmeyen sunucu hatası → Sentry'ye raporla (§4). Yalnız SENTRY_DSN varken
    // init edilmiştir; aksi halde captureException no-op. 4xx istemci hataları RAPORLANMAZ
    // (beklenen: doğrulama, yetki, bulunamadı — Sentry'yi gürültüyle boğardı).
    if (status >= 500) {
      Sentry.captureException(exception);
    }

    const problem: ProblemDetails = {
      type: 'about:blank',
      title: TITLES[status] ?? 'Error',
      status,
      ...(detail ? { detail } : {}),
      ...(code ? { code } : {}),
    };

    res.setHeader('Content-Type', 'application/problem+json');
    res.status(status).send(JSON.stringify(problem));
  }
}
