import { defaultProfile, type Profile } from '../domain/profile.entity';
import type { ProfileRepository } from '../domain/ports';

/** Kimliği doğrulanmış kullanıcının KENDİ profili. Satır yoksa varsayılan döner. */
export class GetProfileUseCase {
  constructor(private readonly profiles: ProfileRepository) {}

  async execute(userId: string): Promise<Profile> {
    const existing = await this.profiles.findByUserId(userId);
    return existing ?? defaultProfile(userId);
  }
}
