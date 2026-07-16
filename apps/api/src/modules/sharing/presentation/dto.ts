import { ApiProperty } from '@nestjs/swagger';

export class NightReportShareDto {
  @ApiProperty({ example: '2026-07-15' }) nightDate!: string;
  @ApiProperty({ example: 'My night: 7h 42m' }) title!: string;
  @ApiProperty({ example: 'Calm 85/100 · NOCTA sleep ritual' }) subtitle!: string;
  @ApiProperty({ example: '7h 42m' }) durationText!: string;
  @ApiProperty({ example: 85 }) calmScore!: number;
  @ApiProperty({ example: 'https://nocta.app' }) webUrl!: string;
  @ApiProperty({ example: 'nocta://report/2026-07-15' }) deepLink!: string;
}

export class ArchetypeShareDto {
  @ApiProperty({ enum: ['deep-ocean', 'overthinker', 'delta-drifter', 'dawn-chaser'] })
  archetypeSlug!: string;
  @ApiProperty({ example: 'My sleep identity is Deep Ocean' }) title!: string;
  @ApiProperty() description!: string;
  @ApiProperty({ example: 'https://nocta.app/a/deep-ocean' }) webUrl!: string;
  @ApiProperty({ example: 'nocta://a/deep-ocean' }) deepLink!: string;
}
