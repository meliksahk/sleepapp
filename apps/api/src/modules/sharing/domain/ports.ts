/** sharing modülü domain portu — archetype sonucunu (başka modül) soyut okur. */
export interface ArchetypeResultView {
  readonly archetypeSlug: string;
}

export interface ArchetypeResultReader {
  /** Kullanıcının en yeni archetype sonucu (yoksa null). userId ile scope'lu. */
  latestFor(userId: string): Promise<ArchetypeResultView | null>;
}

export const ARCHETYPE_RESULT_READER = Symbol('ArchetypeResultReader');
