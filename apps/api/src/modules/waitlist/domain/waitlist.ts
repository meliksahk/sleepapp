/** Ön-lansman bekleme listesi (docs/05 W0). Anonim; e-posta benzersiz. */
export interface WaitlistRepository {
  /** İdempotent — aynı e-posta ikinci kez sorunsuz kabul edilir. */
  add(email: string, source: string | null): Promise<void>;
}

export const WAITLIST_REPOSITORY = Symbol('WaitlistRepository');
