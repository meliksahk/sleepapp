import globals from 'globals';
import base from './base.js';

/**
 * Next.js (apps/admin, apps/web) ESLint temel config. Feature-sliced boundary
 * kuralları (app → features → entities → shared) her app'in kendi
 * eslint.config'inde eslint-plugin-boundaries ile tanımlanır (docs/03 §1.2).
 */
export default [
  ...base,
  {
    languageOptions: {
      globals: { ...globals.browser, ...globals.node },
    },
    rules: {
      'no-console': ['warn', { allow: ['warn', 'error'] }],
    },
  },
];
