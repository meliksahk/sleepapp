import { GetObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import type { AssetUrlSigner } from '../domain/soundscape';

export interface S3SignerConfig {
  readonly endpoint: string;
  readonly region: string;
  readonly accessKey: string;
  readonly secretKey: string;
}

/**
 * S3/MinIO presigned GET URL üreticisi. getSignedUrl OFFLINE'dır (ağ çağrısı yok);
 * dosyanın var olması gerekmez, imza erişimde doğrulanır. API dosya proxy'lemez.
 */
export class S3AssetSigner implements AssetUrlSigner {
  private readonly client: S3Client;

  constructor(config: S3SignerConfig) {
    this.client = new S3Client({
      endpoint: config.endpoint,
      region: config.region,
      credentials: { accessKeyId: config.accessKey, secretAccessKey: config.secretKey },
      forcePathStyle: true, // MinIO path-style
    });
  }

  presignedGetUrl(bucket: string, key: string, expirySeconds: number): Promise<string> {
    return getSignedUrl(this.client, new GetObjectCommand({ Bucket: bucket, Key: key }), {
      expiresIn: expirySeconds,
    });
  }
}
