/** sharing modülü domain portu — archetype sonucunu (başka modül) soyut okur. */
export interface ArchetypeResultView {
  readonly archetypeSlug: string;
}

export interface ArchetypeResultReader {
  /** Kullanıcının en yeni archetype sonucu (yoksa null). userId ile scope'lu. */
  latestFor(userId: string): Promise<ArchetypeResultView | null>;
}

export const ARCHETYPE_RESULT_READER = Symbol('ArchetypeResultReader');

/** Gece raporu görünümü (başka modül — sleep) — paylaşım kartı için. */
export interface NightReportView {
  readonly nightDate: string;
  readonly totalDurationMinutes: number;
  readonly calmScore: number;
}

export interface NightReportReader {
  /** Kullanıcının belirli gece raporu; yoksa null. userId ile scope'lu. */
  reportFor(userId: string, nightDate: string): Promise<NightReportView | null>;
}

export const NIGHT_REPORT_READER = Symbol('NightReportReader');
