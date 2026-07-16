import { ApiProperty } from '@nestjs/swagger';
import { AUDIT_ACTIONS } from '../domain/audit';

export class AuditEntryDto {
  @ApiProperty() id!: string;

  @ApiProperty({ description: 'Eylemi yapan admin (hesap silinse de KORUNUR)' })
  actorEmail!: string;

  @ApiProperty({ enum: AUDIT_ACTIONS }) action!: string;

  @ApiProperty({ description: 'Hedef (soundscape slug)' }) target!: string;

  @ApiProperty({ type: 'object', additionalProperties: true, description: 'Bağlam (PII yok)' })
  details!: Record<string, unknown>;

  @ApiProperty({ description: 'ISO 8601 UTC (CLAUDE.md §4)' }) createdAt!: string;
}
