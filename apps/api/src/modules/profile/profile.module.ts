import { Module, type Provider } from '@nestjs/common';
import { IdentityModule } from '../identity';
import { PrismaService } from '../../shared/infra/prisma.service';
import { PROFILE_REPOSITORY, type ProfileRepository } from './domain/ports';
import { PrismaProfileRepository } from './infrastructure/prisma-profile.repository';
import { GetProfileUseCase } from './application/get-profile.usecase';
import { UpdateProfileUseCase } from './application/update-profile.usecase';
import { ProfileController } from './presentation/profile.controller';

const providers: Provider[] = [
  {
    provide: PROFILE_REPOSITORY,
    inject: [PrismaService],
    useFactory: (prisma: PrismaService): ProfileRepository => new PrismaProfileRepository(prisma),
  },
  {
    provide: GetProfileUseCase,
    inject: [PROFILE_REPOSITORY],
    useFactory: (repo: ProfileRepository): GetProfileUseCase => new GetProfileUseCase(repo),
  },
  {
    provide: UpdateProfileUseCase,
    inject: [PROFILE_REPOSITORY],
    useFactory: (repo: ProfileRepository): UpdateProfileUseCase => new UpdateProfileUseCase(repo),
  },
];

@Module({
  imports: [IdentityModule], // AuthGuard (public API)
  controllers: [ProfileController],
  providers,
  // Modüller-arası okuma için dışa açılır (ör. sleep modülü timezone okur).
  exports: [GetProfileUseCase],
})
export class ProfileModule {}
