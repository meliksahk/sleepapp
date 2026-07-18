import { ApiProperty } from '@nestjs/swagger';

/**
 * Admin kullanıcı arama sonucu (docs/02 §165 destek senaryosu). **Yalnızca kimlik/
 * tür/oluşturma** — parola, token, 2FA gizli anahtarı ASLA burada dönmez.
 */
export class AdminUserDto {
  @ApiProperty({ description: 'Kullanıcı UUID' })
  id!: string;

  @ApiProperty({ enum: ['anonymous', 'registered', 'admin'] })
  kind!: string;

  @ApiProperty({ nullable: true, description: 'Kayıtlı e-posta (anonim kullanıcıda null)' })
  email!: string | null;

  @ApiProperty({ description: 'ISO 8601 oluşturma zamanı (UTC)' })
  createdAt!: string;
}
