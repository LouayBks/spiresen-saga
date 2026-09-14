// @ts-check
const eslint = require('@eslint/js');
const { defineConfig } = require('eslint/config');
const tseslint = require('typescript-eslint');
const angular = require('angular-eslint');
const eslintConfigPrettier = require('eslint-config-prettier');

module.exports = defineConfig([
  {
    files: ['**/*.ts'],
    extends: [
      eslint.configs.recommended,
      tseslint.configs.recommended,
      tseslint.configs.stylistic,
      angular.configs.tsRecommended,
      eslintConfigPrettier,
    ],
    processor: angular.processInlineTemplates,
    rules: {
      '@angular-eslint/directive-selector': [
        'error',
        {
          type: 'attribute',
          prefix: 'app',
          style: 'camelCase',
        },
      ],
      '@angular-eslint/component-selector': [
        'error',
        {
          type: 'element',
          prefix: 'app',
          style: 'kebab-case',
        },
      ],
      // CC-7: no `any` in frontend code
      '@typescript-eslint/no-explicit-any': 'error',
      // CC-10: `interface` for object shapes, `type` only for unions/tuples
      '@typescript-eslint/consistent-type-definitions': ['error', 'interface'],
      // CC-20: no mutating function parameters
      'no-param-reassign': 'error',
      // CC-21: OnPush change detection on every component
      '@angular-eslint/prefer-on-push-component-change-detection': 'error',
      // CC-29: standalone components, inject() over constructor DI
      '@angular-eslint/prefer-standalone': 'error',
      // CC-32: default to private (the `prefer-readonly` half needs type-aware linting,
      // which isn't wired up in this scaffold yet — left as a Skill-based review gap for now)
      '@typescript-eslint/explicit-member-accessibility': ['error', { accessibility: 'explicit' }],
    },
  },
  {
    files: ['**/*.html'],
    extends: [angular.configs.templateRecommended, angular.configs.templateAccessibility],
    rules: {},
  },
]);
