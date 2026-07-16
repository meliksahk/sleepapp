import { ApiProperty } from '@nestjs/swagger';
import { ADMIN_ROLES } from '../../identity';

/** Admin oturum kimliği — panel her sayfa açılışında bunu doğrular. */
export class AdminMeDto {
  @ApiProperty({ description: "Admin kullanıcının id'si" })
  userId!: string;

  @ApiProperty({
    description: 'Bu hesabın sahip olduğu admin rolleri',
    enum: ADMIN_ROLES,
    isArray: true,
  })
  roles!: string[];
}
