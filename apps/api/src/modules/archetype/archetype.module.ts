import { Module, type Provider } from '@nestjs/common';
import { IdentityModule } from '../identity';
import { PrismaService } from '../../shared/infra/prisma.service';
import { ARCHETYPE_RESULT_REPOSITORY, type ArchetypeResultRepository } from './domain/ports';
import {
  SLUG_GENERATOR,
  WEB_ARCHETYPE_RESULT_REPOSITORY,
  type SlugGenerator,
  type WebArchetypeResultRepository,
} from './domain/web';
import { PrismaArchetypeResultRepository } from './infrastructure/prisma-archetype-result.repository';
import { PrismaWebArchetypeResultRepository } from './infrastructure/prisma-web-archetype-result.repository';
import { RandomSlugGenerator } from './infrastructure/random-slug.generator';
import { GetQuestionsUseCase } from './application/get-questions.usecase';
import { SubmitAnswersUseCase } from './application/submit-answers.usecase';
import { GetLatestResultUseCase } from './application/get-latest-result.usecase';
import { ScoreWebUseCase } from './application/score-web.usecase';
import { GetWebResultUseCase } from './application/get-web-result.usecase';
import { ArchetypeController } from './presentation/archetype.controller';
import { WebArchetypeController } from './presentation/web-archetype.controller';

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
  // Public web testi (anonim)
  {
    provide: WEB_ARCHETYPE_RESULT_REPOSITORY,
    inject: [PrismaService],
    useFactory: (prisma: PrismaService): WebArchetypeResultRepository =>
      new PrismaWebArchetypeResultRepository(prisma),
  },
  { provide: SLUG_GENERATOR, useClass: RandomSlugGenerator },
  {
    provide: ScoreWebUseCase,
    inject: [WEB_ARCHETYPE_RESULT_REPOSITORY, SLUG_GENERATOR],
    useFactory: (repo: WebArchetypeResultRepository, slugs: SlugGenerator): ScoreWebUseCase =>
      new ScoreWebUseCase(repo, slugs),
  },
  {
    provide: GetWebResultUseCase,
    inject: [WEB_ARCHETYPE_RESULT_REPOSITORY],
    useFactory: (repo: WebArchetypeResultRepository): GetWebResultUseCase =>
      new GetWebResultUseCase(repo),
  },
];

@Module({
  imports: [IdentityModule],
  controllers: [ArchetypeController, WebArchetypeController],
  providers,
})
export class ArchetypeModule {}
