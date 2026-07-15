import nest from '@nocta/config/eslint/nest';

export default [
  ...nest,
  {
    languageOptions: {
      parserOptions: {
        project: ['./tsconfig.json'],
        tsconfigRootDir: import.meta.dirname,
      },
    },
  },
  {
    ignores: ['dist/**', 'scripts/**', 'eslint.config.mjs', 'jest.config.*'],
  },
];
