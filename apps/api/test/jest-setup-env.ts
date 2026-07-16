// Testler için ortam değişkenlerini kök .env'den yükler (varsa). CI'da DATABASE_URL
// zaten job env'inden gelir; dotenv mevcut env'i EZMEZ. Böylece integration testleri
// hem lokal (docker compose + .env) hem CI (postgres service) ortamında koşar.
import { config } from 'dotenv';
import { resolve } from 'node:path';

config({ path: resolve(__dirname, '../../../.env') });

// Rate-limit testte varsayılan olarak DEVRE DIŞI GİBİ yüksek: e2e'ler tek IP'den
// (127.0.0.1) yüzlerce istek atıyor (ör. 120 uyku oturumu) → gerçek limitle 429
// yerlerdi. Throttling'in KENDİSİ kendi e2e'sinde bu değeri ezerek test edilir
// (throttler.e2e.spec.ts), yani kapsam dışı kalmıyor.
process.env.THROTTLE_LIMIT ??= '100000';
