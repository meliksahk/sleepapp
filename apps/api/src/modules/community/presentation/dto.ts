import { ApiProperty } from '@nestjs/swagger';
import { IsIn, IsInt, IsOptional, IsString, Max, MaxLength, Min, MinLength } from 'class-validator';
import { SOUND_DURATION_MAX_SECONDS, SOUND_TITLE_MAX_LENGTH } from '../domain/user-sound';

export class CreateSoundUploadDto {
  @ApiProperty({ example: 'Yağmurlu balkon', minLength: 1, maxLength: SOUND_TITLE_MAX_LENGTH })
  @IsString()
  @MinLength(1)
  @MaxLength(SOUND_TITLE_MAX_LENGTH)
  title!: string;

  @ApiProperty({ example: 1800, minimum: 1, maximum: SOUND_DURATION_MAX_SECONDS })
  @IsInt()
  @Min(1)
  @Max(SOUND_DURATION_MAX_SECONDS)
  durationSeconds!: number;
}

export class SoundUploadSlotDto {
  @ApiProperty() id!: string;
  @ApiProperty() uploadUrl!: string;
  @ApiProperty() expiresIn!: number;
}

export class UserSoundDto {
  @ApiProperty() id!: string;
  @ApiProperty() title!: string;
  @ApiProperty() status!: string;
  @ApiProperty({ nullable: true }) byteSize!: number | null;
  @ApiProperty() durationSeconds!: number;
  @ApiProperty({ nullable: true }) rejectionReason!: string | null;
  @ApiProperty() createdAt!: string;
}

/** Moderasyon kararı gövdesi — redde gerekçe ZORUNLU (approve'ta alan yok sayılır). */
export class ModerateSoundDto {
  // DİKKAT: whitelist ValidationPipe dekoratörsüz alanları SESSİZCE KIRPAR —
  // decision'sız gelen gövde use case'te "gerekçesiz red" olurdu (testte yakalandı).
  @ApiProperty({ enum: ['approve', 'reject'] })
  @IsIn(['approve', 'reject'])
  decision!: 'approve' | 'reject';

  @ApiProperty({ required: false, maxLength: 500 })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  rejectionReason?: string;
}

export class AdminUserSoundDto extends UserSoundDto {
  @ApiProperty() userId!: string;
  @ApiProperty({ nullable: true }) moderatedAt!: string | null;
}
