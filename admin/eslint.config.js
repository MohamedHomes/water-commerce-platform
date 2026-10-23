import typescriptParser from '@typescript-eslint/parser';
import typescriptPlugin from '@typescript-eslint/eslint-plugin';
import reactHooks from 'eslint-plugin-react-hooks';
import reactRefresh from 'eslint-plugin-react-refresh';

export default [
    {
        ignores: ['dist/**', 'node_modules/**'],
    },
    {
        files: ['**/*.{ts,tsx}'],
        languageOptions: {
            parser: typescriptParser,
            parserOptions: {
                ecmaVersion: 'latest',
                sourceType: 'module',
                ecmaFeatures: { jsx: true },
            },
        },
        plugins: {
            '@typescript-eslint': typescriptPlugin,
            'react-hooks': reactHooks,
            'react-refresh': reactRefresh,
        },
        rules: {
            ...typescriptPlugin.configs.recommended.rules,
            ...reactHooks.configs.recommended.rules,
            'react-refresh/only-export-components': ['error', { allowConstantExport: true }],
        },
    },
];
