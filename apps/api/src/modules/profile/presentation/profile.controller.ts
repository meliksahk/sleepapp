import { Body, Controller, Get, Patch, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { AuthGuard, CurrentUser, type AccessTokenClaims } from '../../identity';
import { GetProfileUseCase } from '../application/get-profile.usecase';
import { UpdateProfileUseCase } from '../application/update-profile.usecase';
import { ProfileResponseDto, UpdateProfileDto } from './dto';

@ApiTags('profile')
@ApiBearerAuth()
@Controller('profile')
@UseGuards(AuthGuard)
export class ProfileController {
  constructor(
    private readonly getProfile: GetProfileUseCase,
    private readonly updateProfile: UpdateProfileUseCase,
  ) {}

  @Get()
  @ApiOperation({ summary: 'Kimliği doğrulanmış kullanıcının kendi profili' })
  @ApiOkResponse({ type: ProfileResponseDto })
  async get(@CurrentUser() user: AccessTokenClaims): Promise<ProfileResponseDto> {
    // Scope daima token'daki sub — istemciden id kabul edilmez ("A, B okuyamaz").
    return this.getProfile.execute(user.sub);
  }

  @Patch()
  @ApiOperation({ summary: 'Kendi profilini güncelle (upsert)' })
  @ApiOkResponse({ type: ProfileResponseDto })
  async update(
    @CurrentUser() user: AccessTokenClaims,
    @Body() dto: UpdateProfileDto,
  ): Promise<ProfileResponseDto> {
    return this.updateProfile.execute(user.sub, {
      displayName: dto.displayName,
      chronotype: dto.chronotype,
      locale: dto.locale,
      timezone: dto.timezone,
      notificationsEnabled: dto.notificationsEnabled,
    });
  }
}
