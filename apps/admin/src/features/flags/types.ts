/**
 * Feature flag tanımının panel görünümü — API `GET /v1/admin/flags` yanıtı
 * (`AdminFlagDto`). Admin HAM kuralı görür (client'ın değerlendirilmiş sonucunun
 * aksine): enabled + rollout% + platform allowlist + asgari sürüm.
 */
export interface AdminFlag {
  key: string;
  rules: FlagRules;
}

export interface FlagRules {
  enabled: boolean;
  rolloutPercentage?: number;
  platforms?: string[];
  minAppVersion?: string;
}
