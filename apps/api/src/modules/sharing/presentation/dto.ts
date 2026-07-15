import { ApiProperty } from '@nestjs/swagger';

export class ArchetypeShareDto {
  @ApiProperty({ enum: ['deep-ocean', 'overthinker', 'delta-drifter', 'dawn-chaser'] })
  archetypeSlug!: string;
  @ApiProperty({ example: 'My sleep identity is Deep Ocean' }) title!: string;
  @ApiProperty() description!: string;
  @ApiProperty({ example: 'https://nocta.app/a/deep-ocean' }) webUrl!: string;
  @ApiProperty({ example: 'nocta://a/deep-ocean' }) deepLink!: string;
}
