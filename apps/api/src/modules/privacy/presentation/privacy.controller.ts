import { Controller, Get, Header, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';

import { AuthGuard, CurrentUser, type AccessTokenClaims } from '../../identity';
import {
  ExportUserDataUseCase,
  type UserDataExport,
} from '../application/export-user-data.usecase';

/**
 * `GET /v1/me/export` — kullanıcı kendi verisini indirir (GDPR taşınabilirliği, D-7).
 * Silme (delete-account) simetriği. Scope = token sub; başkasının verisi asla dönmez.
 */
@ApiTags('privacy')
@ApiBearerAuth()
@Controller('me/export')
@UseGuards(AuthGuard)
export class PrivacyController {
  constructor(private readonly exportUserData: ExportUserDataUseCase) {}

  @Get()
  @ApiOperation({ summary: 'Kullanıcının tüm kişisel verisini JSON olarak dışa aktar' })
  @ApiOkResponse({ description: 'Kullanıcının verisi (profil, arketip, uyku, oturumlar).' })
  // "İndir" davranışı: tarayıcı/istemci dosyaya kaydeder, sayfada açmaz.
  @Header('Content-Disposition', 'attachment; filename="nocta-data-export.json"')
  async export(@CurrentUser() user: AccessTokenClaims): Promise<UserDataExport> {
    return this.exportUserData.execute(user.sub);
  }
}
