import { Global, Module } from '@nestjs/common';
import { PrismaService } from './prisma.service';

/**
 * Tek Prisma bağlantı havuzu tüm modüllere (global). DB dış dünyaya kapalı;
 * her modül yalnızca kendi userId-scope'lu repository'si üzerinden erişir.
 */
@Global()
@Module({
  providers: [PrismaService],
  exports: [PrismaService],
})
export class PrismaModule {}
