import { Controller, Get, UseGuards } from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiForbiddenResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import {
  ADMIN_ROLES,
  AuthGuard,
  CurrentUser,
  Roles,
  RolesGuard,
  isAdminRole,
  type AccessTokenClaims,
} from '../../identity';
import { AdminMeDto } from './dto';

/**
 * Admin panel API'si (docs/03 A0). Bu controller'daki HER uç rol kapılıdır —
 * sınıf düzeyinde `@Roles` ile: yeni bir uç eklerken rol koymayı unutmak
 * "herkese açık admin ucu" demek olurdu, varsayılan kapalı olmalı.
 *
 * Guard SIRASI önemli: AuthGuard req.user'ı doldurur, RolesGuard onu okur.
 */
@ApiTags('admin')
@ApiBearerAuth()
@Controller('admin')
@UseGuards(AuthGuard, RolesGuard)
@Roles(...ADMIN_ROLES)
export class AdminController {
  @Get('me')
  @ApiOperation({ summary: "Admin oturumunu ve rolleri doğrular (panel auth guard'ı)" })
  @ApiOkResponse({ type: AdminMeDto })
  @ApiForbiddenResponse({ description: 'Çağıranın admin rolü yok' })
  me(@CurrentUser() user: AccessTokenClaims): AdminMeDto {
    // Yalnızca TANINAN roller döner: DB'ye elle yazılmış çöp bir rol adı panelin
    // yetki mantığına sızmasın (panel bu listeye göre menü/aksiyon gösterecek).
    return { userId: user.sub, roles: user.roles.filter(isAdminRole) };
  }
}
