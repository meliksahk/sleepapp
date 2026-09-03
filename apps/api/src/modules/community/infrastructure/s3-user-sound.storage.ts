import {
  DeleteObjectCommand,
  GetObjectCommand,
  HeadObjectCommand,
  ListObjectsV2Command,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import type { UserSoundStorage } from '../domain/ports';

export interface S3UserSoundStorageConfig {
  readonly endpoint: string;
  readonly region: string;
  readonly accessKey: string;
  readonly secretKey: string;
}

/**
 * S3/MinIO deposu — `UserSoundStorage` portunun gerçek hâli.
 *
 * S3AssetSigner'dan (content) AYRI sınıf, bilinçli: ortak olan yalnızca SDK
 * kurulumudur; davranış seti farklıdır (PUT imzası + HEAD doğrulaması). İkisini
 * tek "her şeyi yapan" signer'a toplamak, content'in portunu community'nin
 * ihtiyaçlarıyla şişirmek olurdu — modül sınırı kuralı tam da bunu önler.
 */
export class S3UserSoundStorage implements UserSoundStorage {
  private readonly client: S3Client;

  constructor(config: S3UserSoundStorageConfig) {
    this.client = new S3Client({
      endpoint: config.endpoint,
      region: config.region,
      credentials: { accessKeyId: config.accessKey, secretAccessKey: config.secretKey },
      forcePathStyle: true, // MinIO path-style
    });
  }

  presignedPutUrl(bucket: string, key: string, expirySeconds: number): Promise<string> {
    return getSignedUrl(this.client, new PutObjectCommand({ Bucket: bucket, Key: key }), {
      expiresIn: expirySeconds,
    });
  }

  async headObject(bucket: string, key: string): Promise<{ sizeBytes: number } | null> {
    try {
      const head = await this.client.send(new HeadObjectCommand({ Bucket: bucket, Key: key }));
      return { sizeBytes: head.ContentLength ?? 0 };
    } catch (e) {
      // 404 ("NotFound") beklenen bir durumdur: dosya henüz yüklenmemiş.
      // DİĞER hatalar (ağ, kimlik, DNS) gizlenemez — onlar altyapı arızasıdır
      // ve 500'e düşmeli. Sadece "nesne yok" cevabını null'a çeviriyoruz.
      const name = (e as { name?: string })?.name;
      if (name === 'NotFound' || name === 'NoSuchKey' || name === '404') {
        return null;
      }
      throw e;
    }
  }

  presignedGetUrl(bucket: string, key: string, expirySeconds: number): Promise<string> {
    return getSignedUrl(this.client, new GetObjectCommand({ Bucket: bucket, Key: key }), {
      expiresIn: expirySeconds,
    });
  }

  async listKeys(
    bucket: string,
    prefix: string,
  ): Promise<Array<{ key: string; lastModified: Date }>> {
    const out: Array<{ key: string; lastModified: Date }> = [];
    let token: string | undefined;
    do {
      const page = await this.client.send(
        new ListObjectsV2Command({
          Bucket: bucket,
          Prefix: prefix,
          ContinuationToken: token,
        }),
      );
      for (const obj of page.Contents ?? []) {
        if (obj.Key) {
          out.push({ key: obj.Key, lastModified: obj.LastModified ?? new Date(0) });
        }
      }
      token = page.IsTruncated ? page.NextContinuationToken : undefined;
    } while (token);
    return out;
  }

  async removeObject(bucket: string, key: string): Promise<void> {
    // DeleteObject VAR OLMAYAN nesnede de başarılıdır (S3 idempotent silme) —
    // ayrıca try/catch gerektirmez; altyapı hatası yine fırlar ve iş yeniden denenir.
    await this.client.send(new DeleteObjectCommand({ Bucket: bucket, Key: key }));
  }
}
