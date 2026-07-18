import { HttpException, HttpStatus, type ArgumentsHost } from '@nestjs/common';

jest.mock('@sentry/node', () => ({
  init: jest.fn(),
  captureException: jest.fn(),
}));
import * as Sentry from '@sentry/node';

import { initSentry } from '../../src/shared/observability/sentry';
import { ProblemDetailsFilter } from '../../src/shared/http/problem-details.filter';

const init = Sentry.init as unknown as jest.Mock;
const captureException = Sentry.captureException as unknown as jest.Mock;

function fakeHost(): { host: ArgumentsHost } {
  const res = { setHeader: jest.fn(), status: jest.fn().mockReturnThis(), send: jest.fn() };
  return {
    host: {
      switchToHttp: () => ({ getResponse: () => res }),
    } as unknown as ArgumentsHost,
  };
}

describe('initSentry (DSN-gate, §4)', () => {
  beforeEach(() => init.mockClear());

  it('ÇEKİRDEK: DSN yoksa init ETMEZ, false döner (dev/test sessiz)', () => {
    expect(initSentry(undefined, 'test')).toBe(false);
    expect(initSentry('', 'test')).toBe(false);
    expect(init).not.toHaveBeenCalled();
  });

  it('DSN varsa init eder (dsn + environment iletilir), true döner', () => {
    expect(initSentry('https://k@o.ingest.sentry.io/1', 'production')).toBe(true);
    expect(init).toHaveBeenCalledWith(
      expect.objectContaining({ dsn: 'https://k@o.ingest.sentry.io/1', environment: 'production' }),
    );
  });
});

describe('ProblemDetailsFilter → Sentry (yalnız 5xx)', () => {
  const filter = new ProblemDetailsFilter();
  beforeEach(() => captureException.mockClear());

  it('ÇEKİRDEK: 5xx Sentry’ye raporlanır', () => {
    filter.catch(new HttpException('boom', HttpStatus.INTERNAL_SERVER_ERROR), fakeHost().host);
    expect(captureException).toHaveBeenCalledTimes(1);
  });

  it('ÇEKİRDEK: 4xx RAPORLANMAZ (beklenen istemci hatası — gürültü olurdu)', () => {
    filter.catch(new HttpException('bad', HttpStatus.BAD_REQUEST), fakeHost().host);
    filter.catch(new HttpException('nope', HttpStatus.UNAUTHORIZED), fakeHost().host);
    filter.catch(new HttpException('gone', HttpStatus.NOT_FOUND), fakeHost().host);
    expect(captureException).not.toHaveBeenCalled();
  });

  it('beklenmeyen (non-HttpException) hata → 500 kabul edilir → raporlanır', () => {
    filter.catch(new Error('unexpected'), fakeHost().host);
    expect(captureException).toHaveBeenCalledTimes(1);
  });
});
