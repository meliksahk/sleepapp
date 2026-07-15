import next from '@nocta/config/eslint/next';

export default [
  ...next,
  {
    ignores: ['.next/**', 'next-env.d.ts', 'eslint.config.mjs', 'tailwind.config.ts', 'postcss.config.mjs', 'next.config.mjs'],
  },
];
