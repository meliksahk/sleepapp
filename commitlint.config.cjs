/**
 * Conventional Commits — scope = app/paket adı (CLAUDE.md §4).
 * Örnek: feat(mobile): ..., fix(api): ..., chore(repo): ...
 */
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'scope-enum': [
      2,
      'always',
      [
        'mobile',
        'api',
        'admin',
        'web',
        'design-tokens',
        'shared-types',
        'ui',
        'config',
        'db',
        'tooling',
        'ci',
        'deps',
        'repo',
        'docs',
      ],
    ],
    'body-max-line-length': [0, 'always'],
  },
};
