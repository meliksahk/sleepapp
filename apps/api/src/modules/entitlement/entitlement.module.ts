import { Module, type Provider } from '@nestjs/common';

import { IdentityModule } from '../identity';
import { ENTITLEMENT_SERVICE, type EntitlementService } from './domain/entitlement';
import { DevEntitlementService } from './infrastructure/dev-entitlement.service';
import { GetEntitlementUseCase } from './application/get-entitlement.usecase';
import { EntitlementController } from './presentation/entitlement.controller';

const providers: Provider[] = [
  // **IAP geldiğinde (docs/10) YALNIZCA BU SATIR değişir.** Stub → gerçek adaptör.
  { provide: ENTITLEMENT_SERVICE, useClass: DevEntitlementService },
  {
    provide: GetEntitlementUseCase,
    inject: [ENTITLEMENT_SERVICE],
    useFactory: (svc: EntitlementService): GetEntitlementUseCase => new GetEntitlementUseCase(svc),
  },
];

@Module({
  imports: [IdentityModule], // AuthGuard (public API)
  controllers: [EntitlementController],
  providers,
  // Premium kapısı için diğer modüller ENTITLEMENT_SERVICE'i buradan enjekte eder
  // (docs/02 §2 boundary: yalnızca public application/port dışa açılır).
  exports: [ENTITLEMENT_SERVICE],
})
export class EntitlementModule {}
