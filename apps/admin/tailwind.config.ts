import type { Config } from 'tailwindcss';
// Token'lar tek kaynaktan (packages/design-tokens). Hex hard-code YASAK (CLAUDE.md §2).
import preset from '@nocta/design-tokens/tailwind';

export default {
  presets: [preset as Partial<Config>],
  content: ['./src/**/*.{ts,tsx}', '../../packages/ui/src/**/*.{ts,tsx}'],
} satisfies Config;
