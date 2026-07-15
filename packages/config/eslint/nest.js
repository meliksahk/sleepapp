import globals from 'globals';
import base from './base.js';

/**
 * NestJS (apps/api) ESLint config — modüler monolit boundary kuralları burada
 * DEĞİL; her modülün sınırları apps/api'nin kendi eslint.config'inde
 * eslint-plugin-boundaries ile tanımlanır (docs/02 §2.1). Bu dosya yalnızca
 * dil/ortam temelini verir.
 */
export default [
  ...base,
  {
    languageOptions: {
      globals: { ...globals.node },
      parserOptions: {
        sourceType: 'module',
      },
    },
    rules: {
      // Nest decorator/DI desenleri için gevşetmeler
      '@typescript-eslint/no-extraneous-class': 'off',
      '@typescript-eslint/interface-name-prefix': 'off',
    },
  },
];
