import { ApiProperty } from '@nestjs/swagger';
import { IsInt, IsObject } from 'class-validator';

export class SubmitAnswersDto {
  @ApiProperty({ description: 'Soru matrisi sürümü', example: 1 })
  @IsInt()
  version!: number;

  @ApiProperty({
    description: 'questionId → optionId eşlemesi',
    example: { q1: 'q1a', q2: 'q2b' },
    additionalProperties: { type: 'string' },
  })
  @IsObject()
  answers!: Record<string, string>;
}

export class QuestionOptionDto {
  @ApiProperty() id!: string;
  @ApiProperty() label!: string;
  @ApiProperty({ enum: ['deep-ocean', 'overthinker', 'delta-drifter', 'dawn-chaser'] })
  archetype!: string;
}
export class QuestionDto {
  @ApiProperty() id!: string;
  @ApiProperty() prompt!: string;
  @ApiProperty({ type: [QuestionOptionDto] }) options!: QuestionOptionDto[];
}
export class QuestionsResponseDto {
  @ApiProperty({ example: 1 }) version!: number;
  @ApiProperty({ type: [QuestionDto] }) questions!: QuestionDto[];
}

export class ArchetypeResultResponseDto {
  @ApiProperty({ format: 'uuid' }) userId!: string;
  @ApiProperty({ enum: ['deep-ocean', 'overthinker', 'delta-drifter', 'dawn-chaser'] })
  archetypeSlug!: string;
  @ApiProperty({ type: 'object', additionalProperties: { type: 'number' } })
  scores!: Record<string, number>;
  @ApiProperty({ example: 1 }) version!: number;
  @ApiProperty({ format: 'date-time' }) createdAt!: Date;
}
