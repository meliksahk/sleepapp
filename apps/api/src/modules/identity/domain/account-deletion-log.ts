/**
 * Hesap silme sayacı portu.
 *
 * **NEDEN AYRI BİR PORT:** `users` satırı HARD delete ediliyor (FK ON DELETE
 * CASCADE). Satır gidince "kaç hesap silindi" sorusunun cevabı da gidiyor —
 * panelde silme kaskadının gerçekten işlediğini görmenin başka yolu yok.
 *
 * **KULLANICI KİMLİĞİ TUTULMAZ.** Bu bir olay sayacıdır, kayıt defteri değil:
 * silinen kullanıcının izini bırakmak "sil" sözünü bozardı (KVKK/GDPR) ve
 * user_id tutulsaydı kaskad bu satırı da silip sayacı hep 0 bırakırdı.
 */
export interface AccountDeletionLog {
  /**
   * Bir silme olayını işaretler.
   *
   * **ASLA ATMAZ:** sayaç yazımı başarısız olursa kullanıcının silme işlemi de
   * başarısız olurdu. Kullanıcının hesabını silme hakkı, bizim istatistiğimizden
   * önce gelir (denetim izindeki kararın aynısı — bkz. `AuditLog.record`).
   */
  record(): Promise<void>;

  /** [since] tarihinden bu yana silinen hesap sayısı. */
  countSince(since: Date): Promise<number>;
}

export const ACCOUNT_DELETION_LOG = Symbol('AccountDeletionLog');
