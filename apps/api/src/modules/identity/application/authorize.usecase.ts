import type { AccessTokenClaims } from '../domain/user.entity';
import { InvalidAccessTokenError } from '../domain/errors';
import type { AccessTokenSigner } from '../domain/ports';

/**
 * Access token doğrulama — guard bunu kullanır. Diğer modüller kendi kripto/JWT
 * kodunu YAZMAZ; yalnızca guard'dan gelen { sub, roles } context'ini kullanır.
 */
export class AuthorizeUseCase {
  constructor(private readonly signer: AccessTokenSigner) {}

  async execute(bearerToken: string): Promise<AccessTokenClaims> {
    try {
      return await this.signer.verify(bearerToken);
    } catch {
      throw new InvalidAccessTokenError();
    }
  }
}
