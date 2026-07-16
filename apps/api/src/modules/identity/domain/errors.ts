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

export class EmailAlreadyTakenError extends IdentityError {
  constructor() {
    super('email_taken', 'Bu e-posta başka bir hesapta kullanılıyor.');
  }
}

export class InvalidMagicLinkError extends IdentityError {
  constructor() {
    super('invalid_magic_link', 'Magic link geçersiz, kullanılmış veya süresi dolmuş.');
  }
}

/**
 * Admin girişi başarısız. E-posta yok / parola yanlış / hesap admin değil —
 * HEPSİ aynı hata: hangisinin olduğunu söylemek kullanıcı sayımına davetiye olurdu.
 */
export class InvalidCredentialsError extends IdentityError {
  constructor() {
    super('invalid_credentials', 'E-posta veya parola hatalı.');
  }
}

/**
 * Parola DOĞRU ama 2FA kodu gerekiyor/geçersiz.
 *
 * NEDEN InvalidCredentialsError'DAN AYRI: parolanın doğru olduğunu zaten kanıtladık;
 * "kod da lazım" demek burada yeni bir bilgi sızdırmaz — panelin kod alanını
 * göstermesi için bunu BİLMESİ gerekir. Sızıntı endişesi kod hatasında da yok:
 * saldırgan bu noktaya ancak geçerli parolayla gelebilir.
 */
export class TotpRequiredError extends IdentityError {
  constructor() {
    super('totp_required', 'İki adımlı doğrulama kodu gerekli.');
  }
}

export class InvalidTotpError extends IdentityError {
  constructor() {
    super('invalid_totp', 'İki adımlı doğrulama kodu geçersiz.');
  }
}

/** Zaten onaylanmış 2FA yeniden kurulamaz (bkz. EnrollTotpUseCase). */
export class TotpAlreadyEnabledError extends IdentityError {
  constructor() {
    super('totp_already_enabled', 'İki adımlı doğrulama zaten etkin.');
  }
}
