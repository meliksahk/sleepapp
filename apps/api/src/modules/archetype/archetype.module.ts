import { Module, type Provider } from '@nestjs/common';
import { IdentityModule } from '../identity';
import { PrismaService } from '../../shared/infra/prisma.service';
import { ARCHETYPE_RESULT_REPOSITORY, type ArchetypeResultRepository } from './domain/ports';
import { PrismaArchetypeResultRepository } from './infrastructure/prisma-archetype-result.repository';
import { GetQuestionsUseCase } from './application/get-questions.usecase';
import { SubmitAnswersUseCase } from './application/submit-answers.usecase';
import { GetLatestResultUseCase } from './application/get-latest-result.usecase';
import { ArchetypeController } from './presentation/archetype.controller';

const providers: Provider[] = [
  {
    provide: ARCHETYPE_RESULT_REPOSITORY,
    inject: [PrismaService],
    useFactory: (prisma: PrismaService): ArchetypeResultRepository =>
      new PrismaArchetypeResultRepository(prisma),
  },
  {
    provide: GetQuestionsUseCase,
    useFactory: (): GetQuestionsUseCase => new GetQuestionsUseCase(),
  },
  {
    provide: SubmitAnswersUseCase,
    inject: [ARCHETYPE_RESULT_REPOSITORY],
    useFactory: (repo: ArchetypeResultRepository): SubmitAnswersUseCase =>
      new SubmitAnswersUseCase(repo),
  },
  {
    provide: GetLatestResultUseCase,
    inject: [ARCHETYPE_RESULT_REPOSITORY],
    useFactory: (repo: ArchetypeResultRepository): GetLatestResultUseCase =>
      new GetLatestResultUseCase(repo),
  },
];

@Module({
  imports: [IdentityModule],
  controllers: [ArchetypeController],
  providers,
})
export class ArchetypeModule {}
