import { randomUUID } from 'node:crypto';
import { Injectable, Logger, NestMiddleware } from '@nestjs/common';
import type { NextFunction, Request, Response } from 'express';

/**
 * Correlation-id (x-request-id) — verilmişse echo, yoksa üretir. MIDDLEWARE olduğu
 * için guard'lardan ÖNCE çalışır → 401/403 dahil TÜM yanıtlarda header bulunur.
 * Prod'da erişim logu (docs/07). Sentry bu id'yi tag olarak kullanacak.
 */
@Injectable()
export class RequestIdMiddleware implements NestMiddleware {
  private readonly logger = new Logger('HTTP');
  private readonly logRequests = process.env.NODE_ENV !== 'test';

  use(req: Request, res: Response, next: NextFunction): void {
    const incoming = req.headers['x-request-id'];
    const id = typeof incoming === 'string' && incoming.length > 0 ? incoming : randomUUID();
    res.setHeader('x-request-id', id);

    if (this.logRequests) {
      const start = Date.now();
      res.on('finish', () => {
        this.logger.log(
          `${req.method} ${req.originalUrl} ${res.statusCode} ${Date.now() - start}ms [${id}]`,
        );
      });
    }
    next();
  }
}
