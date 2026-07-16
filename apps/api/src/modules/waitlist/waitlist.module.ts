import { Module, type Provider } from '@nestjs/common';
import { PrismaService } from '../../shared/infra/prisma.service';
import { WAITLIST_REPOSITORY, type WaitlistRepository } from './domain/waitlist';
import { PrismaWaitlistRepository } from './infrastructure/prisma-waitlist.repository';
import { JoinWaitlistUseCase } from './application/join-waitlist.usecase';
import { CountWaitlistUseCase } from './application/count-waitlist.usecase';
import { WaitlistController } from './presentation/waitlist.controller';

const providers: Provider[] = [
  {
    provide: WAITLIST_REPOSITORY,
    inject: [PrismaService],
    useFactory: (prisma: PrismaService): WaitlistRepository => new PrismaWaitlistRepository(prisma),
  },
  {
    provide: JoinWaitlistUseCase,
    inject: [WAITLIST_REPOSITORY],
    useFactory: (repo: WaitlistRepository): JoinWaitlistUseCase => new JoinWaitlistUseCase(repo),
  },
  {
    provide: CountWaitlistUseCase,
    inject: [WAITLIST_REPOSITORY],
    useFactory: (repo: WaitlistRepository): CountWaitlistUseCase => new CountWaitlistUseCase(repo),
  },
];

@Module({
  controllers: [WaitlistController],
  providers,
  // Yalnızca sayım dışa açılır; katılım akışı waitlist'e özeldir.
  exports: [CountWaitlistUseCase],
})
export class WaitlistModule {}
