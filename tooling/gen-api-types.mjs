// gen:api-types zinciri (cross-platform — Windows/Linux). OpenAPI'yi api'den
// yeniden üretip TS tiplerini oluşturur. Elle tip yazmak yasak (CLAUDE.md §2).
import { execSync } from 'node:child_process';

const steps = [
  ['api build', 'pnpm --filter @nocta/api build'],
  ['openapi export', 'pnpm --filter @nocta/api openapi:export'],
  ['ts types gen', 'pnpm --filter @nocta/shared-types gen'],
];

for (const [label, cmd] of steps) {
  console.warn(`[gen:api-types] ${label} …`);
  execSync(cmd, { stdio: 'inherit' });
}
console.warn('[gen:api-types] tamam → packages/shared-types/src/generated/api.ts');
