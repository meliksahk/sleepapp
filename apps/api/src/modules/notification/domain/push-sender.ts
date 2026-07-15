/** Push gönderim portu (docs/02 B3). Gerçek APNs/FCM adaptörü docs/10'a ertelendi. */

export interface PushMessage {
  readonly title: string;
  readonly body: string;
  /** İsteğe bağlı derin-link / veri yükü (ör. rapor id'si). */
  readonly data?: Record<string, string>;
}

export interface PushTarget {
  readonly token: string;
  readonly platform: string;
}

export interface PushSender {
  /** Tek hedefe gönderir. Başarısızlıkta fırlatır (fan-out başına-hedef izole eder). */
  send(target: PushTarget, message: PushMessage): Promise<void>;
}

export const PUSH_SENDER = Symbol('PushSender');
