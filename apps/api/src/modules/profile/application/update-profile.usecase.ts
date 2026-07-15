import type { Profile, ProfileUpdate } from '../domain/profile.entity';
import type { ProfileRepository } from '../domain/ports';

/** Kendi profilini günceller (upsert). Scope daima authenticated userId. */
export class UpdateProfileUseCase {
  constructor(private readonly profiles: ProfileRepository) {}

  async execute(userId: string, update: ProfileUpdate): Promise<Profile> {
    return this.profiles.upsert(userId, update);
  }
}
