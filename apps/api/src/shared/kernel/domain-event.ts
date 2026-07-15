/**
 * Domain event tabanı + outbox kaydı arayüzü (docs/02 §2 shared/kernel).
 * F0'da tanım seviyesinde; outbox publisher worker'ı B3'te devreye girer.
 */
export interface DomainEvent {
  readonly type: string;
  readonly occurredAt: Date;
  readonly aggregateId: string;
  readonly payload: Record<string, unknown>;
}

export interface OutboxRecord extends DomainEvent {
  readonly id: string;
  readonly publishedAt: Date | null;
}
