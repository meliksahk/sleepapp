/** identity domain hataları — tipli hiyerarşi (CLAUDE.md §4). */
export class IdentityError extends Error {
  constructor(
    public readonly code: string,
    message: string,
  ) {
    super(message);
    this.name = 'IdentityError';
  }
}

export class InvalidRefreshTokenError extends IdentityError {
  constructor() {
    super('invalid_refresh_token', 'Refresh token geçersiz veya süresi dolmuş.');
  }
}

/**
 * Reuse-detection: iptal edilmiş (rotasyona uğramış) bir refresh token yeniden
 * kullanıldı → çalıntı kabul edilir, tüm oturum ailesi düşürülür (docs/02 §2.1).
 */
export class RefreshTokenReuseError extends IdentityError {
  constructor() {
    super(
      'refresh_token_reuse',
      'Refresh token yeniden kullanımı tespit edildi; oturumlar düşürüldü.',
    );
  }
}

export class InvalidAccessTokenError extends IdentityError {
  constructor() {
    super('invalid_access_token', 'Access token geçersiz.');
  }
}
