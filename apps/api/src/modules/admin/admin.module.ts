import { Module } from '@nestjs/common';
import { IdentityModule } from '../identity';
import { AdminController } from './presentation/admin.controller';

/**
 * Admin modülü (docs/02 §2). A0: yalnızca oturum/rol doğrulama.
 * İçerik CMS'i ve metrikler A1–A3'te; onlar da diğer modüllerin PUBLIC
 * application servislerinden tüketilir (repo/Prisma modeline dokunulmaz).
 */
@Module({
  imports: [IdentityModule],
  controllers: [AdminController],
})
export class AdminModule {}
