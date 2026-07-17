/**
 * Kullanıcının kendi verisinin tam dışa aktarımı (GDPR taşınabilirliği, D-7).
 *
 * **Neden var — silmenin simetriği:** hesap silme (delete-account) zaten vardı ama
 * "verimi indir" yoktu. GDPR Md.20 (taşınabilirlik) ve App Store veri şeffaflığı bunu
 * ister.
 *
 * **Neden LOCAL port (`ExportSources`), başka modülü doğrudan import ETMİYORUZ:**
 * modül-sınır kuralı (docs/02 §2) application katmanının başka modülün public API'sine
 * bağlanmasını yasaklar (eslint boundaries). Bu yüzden use case yalnızca kendi local
 * port'una bağlıdır; gerçek modüllerin read use case'leri `privacy.module`'de bu porta
 * adapte edilir — sleep'in `ProfileTimezoneReader` deseniyle birebir aynı.
 *
 * **Kapsam (D-7 "anlamlı veri"):** profil, arketip geçmişi, uyku oturumları, aktif
 * cihaz/oturumlar. **Push cihaz token'ları HARİÇ** — opak altyapı kimlikleri, anlamlı
 * içerik değil. Ham mikrofon verisi sunucuya HİÇ gelmez (CLAUDE.md §6) → export edilecek
 * bir şey yok.
 */

/** privacy'nin ihtiyaç duyduğu okuma kaynakları — hepsi userId ile scope'lu. */
export interface ExportSources {
  profile(userId: string): Promise<unknown>;
  archetypeResults(userId: string): Promise<readonly unknown[]>;
  sleepSessions(userId: string): Promise<readonly unknown[]>;
  sessions(userId: string): Promise<readonly unknown[]>;
}

export const EXPORT_SOURCES = Symbol('ExportSources');

export interface UserDataExport {
  readonly exportedAt: string;
  readonly account: { readonly sessions: readonly unknown[] };
  readonly profile: unknown;
  readonly archetypeResults: readonly unknown[];
  readonly sleepSessions: readonly unknown[];
}

export class ExportUserDataUseCase {
  constructor(private readonly sources: ExportSources) {}

  async execute(userId: string): Promise<UserDataExport> {
    // Hepsi userId ile scope'lu (repository katmanı zorunlu kılar) → "A, B'nin
    // verisini export edemez" tasarım gereği garanti. Paralel: bağımsız okumalar.
    const [profile, archetypeResults, sleepSessions, sessions] = await Promise.all([
      this.sources.profile(userId),
      this.sources.archetypeResults(userId),
      this.sources.sleepSessions(userId),
      this.sources.sessions(userId),
    ]);

    return {
      exportedAt: new Date().toISOString(),
      account: { sessions },
      profile,
      archetypeResults,
      sleepSessions,
    };
  }
}
