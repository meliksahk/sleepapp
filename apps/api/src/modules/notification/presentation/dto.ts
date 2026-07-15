import { ApiProperty } from '@nestjs/swagger';
import { IsIn, IsString, MaxLength, MinLength } from 'class-validator';

export class RegisterTokenDto {
  @ApiProperty({ description: 'APNs/FCM push token' })
  @IsString()
  @MinLength(8)
  @MaxLength(512)
  token!: string;

  @ApiProperty({ enum: ['ios', 'android'] })
  @IsIn(['ios', 'android'])
  platform!: string;
}
