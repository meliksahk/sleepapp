// Testler için ortam değişkenlerini kök .env'den yükler (varsa). CI'da DATABASE_URL
// zaten job env'inden gelir; dotenv mevcut env'i EZMEZ. Böylece integration testleri
// hem lokal (docker compose + .env) hem CI (postgres service) ortamında koşar.
import { config } from 'dotenv';
import { resolve } from 'node:path';

config({ path: resolve(__dirname, '../../../.env') });
