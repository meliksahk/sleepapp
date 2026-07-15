import type { Profile, ProfileUpdate } from './profile.entity';

/** profiles erişimi — her metod userId ile scope'lanır (docs/02 §2.1). */
export interface ProfileRepository {
  findByUserId(userId: string): Promise<Profile | null>;
  upsert(userId: string, update: ProfileUpdate): Promise<Profile>;
}

export const PROFILE_REPOSITORY = Symbol('ProfileRepository');
