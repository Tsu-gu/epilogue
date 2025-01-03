import js from '@eslint/js';
import { includeIgnoreFile } from '@eslint/compat';
import svelte from 'eslint-plugin-svelte';
import globals from 'globals';
import { fileURLToPath } from 'node:url';
const gitignorePath = fileURLToPath(new URL("./.gitignore", import.meta.url));

/** @type {import('eslint').Linter.Config[]} */
export default [
  includeIgnoreFile(gitignorePath),
  js.configs.recommended,
  ...svelte.configs["flat/recommended"],
  {
    languageOptions: {
	  globals: {
	    ...globals.browser,
	    ...globals.node
	  }
	}
  }
];
