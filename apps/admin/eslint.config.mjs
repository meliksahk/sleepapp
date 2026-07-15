import next from '@nocta/config/eslint/next';
import boundaries from 'eslint-plugin-boundaries';

/**
 * Feature-sliced katman sınırları (docs/03 §3.3). eslint-plugin-boundaries ile zorlanır:
 * app → features → entities → shared (üst kat alta bağımlı olabilir, tersi YASAK).
 * app yalnızca kompozisyon; shared hiçbir üst katı import edemez.
 */
export default [
  ...next,
  {
    files: ['src/**/*.{ts,tsx}'],
    plugins: { boundaries },
    settings: {
      // boundaries import'ları TS resolver ile çözer (aksi halde element sınıflanmaz).
      'import/resolver': {
        typescript: { alwaysTryTypes: true, project: './tsconfig.json' },
        node: { extensions: ['.ts', '.tsx', '.js', '.json'] },
      },
      'boundaries/include': ['src/**/*.{ts,tsx}'],
      'boundaries/elements': [
        { type: 'app', pattern: 'src/app', mode: 'folder' },
        { type: 'features', pattern: 'src/features/*', mode: 'folder', capture: ['feature'] },
        { type: 'entities', pattern: 'src/entities/*', mode: 'folder', capture: ['entity'] },
        { type: 'shared', pattern: 'src/shared/*', mode: 'folder', capture: ['segment'] },
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
            // app: kompozisyon — tüm alt katlar
            { from: ['app'], allow: ['app', 'features', 'entities', 'shared'] },
            // features: alt katlar + kendi kardeş dilimleri
            { from: ['features'], allow: ['features', 'entities', 'shared'] },
            // entities: alt katlar
            { from: ['entities'], allow: ['entities', 'shared'] },
            // shared: yalnızca shared (en alt kat — üst katları göremez)
            { from: ['shared'], allow: ['shared'] },
          ],
        },
      ],
    },
  },
  {
    ignores: [
      '.next/**',
      'next-env.d.ts',
      'eslint.config.mjs',
      'tailwind.config.ts',
      'postcss.config.mjs',
      'next.config.mjs',
    ],
  },
];
