import { Module, type Provider } from '@nestjs/common';
import { IdentityModule } from '../identity';
import { PrismaService } from '../../shared/infra/prisma.service';
import {
  BUCKET_HASHER,
  FLAG_REPOSITORY,
  type BucketHasher,
  type FlagRepository,
} from './domain/flag';
import { PrismaFlagRepository } from './infrastructure/prisma-flag.repository';
import { CryptoBucketHasher } from './infrastructure/crypto-bucket-hasher';
import { GetFlagsUseCase } from './application/get-flags.usecase';
import { ListAllFlagsUseCase } from './application/list-all-flags.usecase';
import { FlagsController } from './presentation/flags.controller';

const providers: Provider[] = [
  { provide: BUCKET_HASHER, useClass: CryptoBucketHasher },
  {
    provide: FLAG_REPOSITORY,
    inject: [PrismaService],
    useFactory: (prisma: PrismaService): FlagRepository => new PrismaFlagRepository(prisma),
  },
  {
    provide: GetFlagsUseCase,
    inject: [FLAG_REPOSITORY, BUCKET_HASHER],
    useFactory: (repo: FlagRepository, hasher: BucketHasher): GetFlagsUseCase =>
      new GetFlagsUseCase(repo, hasher),
  },
  {
    provide: ListAllFlagsUseCase,
    inject: [FLAG_REPOSITORY],
    useFactory: (repo: FlagRepository): ListAllFlagsUseCase => new ListAllFlagsUseCase(repo),
  },
];

@Module({
  imports: [IdentityModule],
  controllers: [FlagsController],
  providers,
  // Admin paneli ham flag tanımlarını buradan okur (docs/03 A4).
  exports: [ListAllFlagsUseCase],
})
export class FlagsModule {}
