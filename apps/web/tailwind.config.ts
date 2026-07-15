import type { Config } from 'tailwindcss';
import preset from '@nocta/design-tokens/tailwind';

export default {
  presets: [preset as Partial<Config>],
  content: ['./src/**/*.{ts,tsx}'],
} satisfies Config;
