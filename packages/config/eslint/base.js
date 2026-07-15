import eslint from '@eslint/js';
import tseslint from 'typescript-eslint';
import prettier from 'eslint-config-prettier';

/**
 * NOCTA temel ESLint flat config — tüm TS yüzeyleri (CLAUDE.md §4).
 * `any` yasak (unknown + narrowing), boş catch yasak.
 */
export default tseslint.config(
  eslint.configs.recommended,
  ...tseslint.configs.recommended,
  {
    rules: {
      '@typescript-eslint/no-explicit-any': 'error',
      '@typescript-eslint/no-unused-vars': [
        'error',
        { argsIgnorePattern: '^_', varsIgnorePattern: '^_' },
      ],
      'no-empty': ['error', { allowEmptyCatch: false }],
      'no-console': ['warn', { allow: ['warn', 'error'] }],
      eqeqeq: ['error', 'smart'],
    },
  },
  prettier,
  {
    ignores: ['dist/**', 'build/**', '.next/**', 'coverage/**', '**/generated/**', '*.config.js'],
  },
);
