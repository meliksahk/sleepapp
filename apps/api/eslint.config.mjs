import nest from '@nocta/config/eslint/nest';
import boundaries from 'eslint-plugin-boundaries';

/**
 * Hexagonal modül sınırları (docs/02 §2.1). eslint-plugin-boundaries ile zorlanır:
 * - domain hiçbir şeyi import etmez (yalnızca kendi domain'i).
 * - application yalnızca kendi domain'i + shared.
 * - presentation, infrastructure'ı import EDEMEZ.
 * - modüller arası erişim YALNIZCA hedef modülün public barrel'ı (index.ts) üzerinden.
 * `${from.module}` capture'ı ile aynı-modül kısıtı uygulanır.
 */
const ownModule = (type) => [type, { module: '${from.module}' }];

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
    files: ['src/**/*.ts'],
    plugins: { boundaries },
    settings: {
      // boundaries import'ları TS resolver ile çözer (aksi halde element sınıflanmaz).
      'import/resolver': {
        typescript: { alwaysTryTypes: true, project: './tsconfig.json' },
        node: { extensions: ['.ts', '.js', '.json'] },
      },
      'boundaries/include': ['src/**/*.ts'],
      'boundaries/elements': [
        { type: 'domain', pattern: 'src/modules/*/domain', mode: 'folder', capture: ['module'] },
        {
          type: 'application',
          pattern: 'src/modules/*/application',
          mode: 'folder',
          capture: ['module'],
        },
        {
          type: 'infrastructure',
          pattern: 'src/modules/*/infrastructure',
          mode: 'folder',
          capture: ['module'],
        },
        {
          type: 'presentation',
          pattern: 'src/modules/*/presentation',
          mode: 'folder',
          capture: ['module'],
        },
        { type: 'module-api', pattern: 'src/modules/*/index.ts', mode: 'file', capture: ['module'] },
        {
          type: 'module-def',
          pattern: 'src/modules/*/*.module.ts',
          mode: 'file',
          capture: ['module'],
        },
        { type: 'shared', pattern: 'src/shared/*', mode: 'folder', capture: ['segment'] },
        { type: 'app', pattern: 'src/*', mode: 'file' },
      ],
    },
    rules: {
      'boundaries/no-unknown': 'off',
      'boundaries/no-unknown-files': 'off',
      'boundaries/element-types': [
        'error',
        {
          default: 'disallow',
          rules: [
            // domain: yalnızca kendi domain'i (saf TS, IO yok)
            { from: ['domain'], allow: [ownModule('domain')] },
            // application: kendi domain'i + application + shared
            {
              from: ['application'],
              allow: [ownModule('application'), ownModule('domain'), 'shared'],
            },
            // infrastructure: kendi domain/application/infrastructure + shared
            {
              from: ['infrastructure'],
              allow: [
                ownModule('infrastructure'),
                ownModule('domain'),
                ownModule('application'),
                'shared',
              ],
            },
            // presentation: kendi application/domain/presentation + BAŞKA modül public barrel
            {
              from: ['presentation'],
              allow: [
                ownModule('presentation'),
                ownModule('application'),
                ownModule('domain'),
                'module-api',
              ],
            },
            // module barrel: kendi modül katmanlarını re-export eder
            {
              from: ['module-api'],
              allow: [
                ownModule('module-def'),
                ownModule('presentation'),
                ownModule('application'),
                ownModule('domain'),
                ownModule('infrastructure'),
              ],
            },
            // module tanımı: kendi katmanları + başka modül barrel + shared
            {
              from: ['module-def'],
              allow: [
                ownModule('domain'),
                ownModule('application'),
                ownModule('infrastructure'),
                ownModule('presentation'),
                'module-api',
                'shared',
              ],
            },
            // app kökü: modül tanımları + barrel + shared + app
            { from: ['app'], allow: ['module-def', 'module-api', 'shared', 'app'] },
            // shared: yalnızca shared
            { from: ['shared'], allow: ['shared'] },
          ],
        },
      ],
    },
  },
  {
    ignores: ['dist/**', 'scripts/**', 'eslint.config.mjs', 'jest.config.*'],
  },
];
