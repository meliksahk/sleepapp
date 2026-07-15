import next from '@nocta/config/eslint/next';

export default [
  ...next,
  {
    ignores: ['eslint.config.mjs', 'vitest.config.ts', 'vitest.setup.ts'],
  },
];
