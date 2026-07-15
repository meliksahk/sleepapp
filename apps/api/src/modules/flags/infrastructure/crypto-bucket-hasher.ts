import { createHash } from 'node:crypto';
import type { BucketHasher } from '../domain/flag';

/** sha256(userId:key) ilk 4 baytı → 0-99 kova. Deterministik + eşit dağılım. */
export class CryptoBucketHasher implements BucketHasher {
  bucket(userId: string, key: string): number {
    const digest = createHash('sha256').update(`${userId}:${key}`).digest();
    const n = digest.readUInt32BE(0);
    return n % 100;
  }
}
