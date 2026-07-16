export type SoundscapeStatus = 'draft' | 'scheduled' | 'published';

/** API'nin /v1/admin/soundscapes yanıtı (bkz. AdminSoundscapeDto). */
export interface AdminSoundscape {
  id: string;
  slug: string;
  title: string;
  status: SoundscapeStatus;
  archetypeAffinity: string[];
  version: number;
  createdAt: string;
}
