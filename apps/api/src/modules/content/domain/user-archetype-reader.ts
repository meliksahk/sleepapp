/**
 * Kullanıcının en son archetype sonucunu (slug) okuyan port (cross-module: archetype).
 * Content, archetype modülünün sonucuna port + module-def adaptörü üzerinden erişir;
 * archetype tablosuna DOKUNMAZ (sleep→profile timezone deseninin aynısı).
 */
export interface UserArchetypeReader {
  /** Kullanıcının archetype slug'ı; hiç test yapılmadıysa undefined. */
  archetypeFor(userId: string): Promise<string | undefined>;
}

export const USER_ARCHETYPE_READER = Symbol('UserArchetypeReader');
