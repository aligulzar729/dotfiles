---
name: install-anti-slop
description: Install and configure the anti-slop plugin, for Oxlint or for ESLint and Prettier, in a local TypeScript or JavaScript repository. Use whenever a user asks to add anti-slop lint rules, copy the anti-slop plugin, configure opinionated Oxlint or ESLint rules, or migrate an existing local anti-slop setup.
---

# Install anti-slop

Install the bundled plugin into the current repository and integrate it with the repository's existing lint setup. Preserve unrelated work and adapt to the project's package manager and configuration style.

The same rules ship in two flavors. Pick the one the repository already lints with; install both only when the repository already runs both linters.

- **Oxlint** — `--flavor oxlint` (default). Follow the [Oxlint procedure](#oxlint-procedure).
- **ESLint (with Prettier)** — `--flavor eslint`. Follow the [ESLint and Prettier procedure](#eslint-and-prettier-procedure).

## Oxlint procedure

1. Inspect the repository before changing it:
   - Read its agent instructions.
   - Check `git status` and preserve unrelated changes.
   - Identify the package manager from `packageManager` and lockfiles.
   - Find Oxlint configuration (`oxlint.config.*`, `.oxlintrc*`, or a Vite+ config).
   - Check whether anti-slop files or rules already exist. Do not overwrite them without reviewing the diff.

2. Copy the bundled plugin from this skill. Run from the target repository:

   ```bash
   node <skill-directory>/scripts/install.mjs
   ```

   This creates `tools/oxlint/anti-slop/`. Pass another relative destination as the first argument when the repository has an established tooling layout. The script refuses to replace an existing destination; only use `--force` after backing up and reviewing existing files.

3. Install current compatible dependencies rather than trusting versions remembered by the agent:
   - Query `npm view oxlint version` and `npm view @oxlint/plugins version`.
   - Install the same current version of both packages with the repository's package manager.
   - `oxlint` is a development dependency. The copied source imports `@oxlint/plugins`, so install it as a development dependency for a local-only plugin.
   - Do not replace the package manager or rewrite unrelated dependency ranges.

4. Register the plugin, configure ignores, and enable all rules. For `oxlint.config.ts` or `.oxlintrc.json`, merge these fields with the existing configuration:

   ```ts
   ignorePatterns: [
     ".agent/**",
     ".agents/**",
     ".claude/**",
     ".codex/**",
     ".continue/**",
     ".cursor/**",
     ".gemini/**",
     ".opencode/**",
     ".pi/**",
     ".roo/**",
     ".windsurf/**",
     "tools/oxlint/anti-slop/**",
   ],
   jsPlugins: [
     { name: "anti-slop", specifier: "./tools/oxlint/anti-slop/index.ts" },
   ],
   ```

   Keep every existing ignore. Adjust the final pattern when the plugin was copied elsewhere. Inspect the repository for other project-local agent tooling directories and add them rather than linting installed skills, hooks, or generated agent configuration as application source. Do not broadly ignore all dot-directories, because some repositories keep owned source or checks in them.

   For Vite+, add these fields to `lint.ignorePatterns` and `lint.jsPlugins`. Also merge the same patterns into `fmt.ignorePatterns` so `vp check` does not reformat installed agent assets or the vendored plugin. Merge existing entries instead of replacing them.

   Enable these rules at `"error"`:

   ```json
   {
     "anti-slop/no-chained-type-assertions": "error",
     "anti-slop/no-conditional-empty-object-spread": "error",
     "anti-slop/no-known-value-widening": "error",
     "anti-slop/no-module-mocking": "error",
     "anti-slop/no-object-parameters": "error",
     "anti-slop/no-reflect-apply": "error",
     "anti-slop/no-reflect-get": "error",
     "anti-slop/no-runtime-typeof": "error",
     "anti-slop/no-shape-in-symbol-names": "error",
     "anti-slop/no-unknown-parameters": "error",
     "anti-slop/no-unknown-returns": "error",
     "anti-slop/no-unknown-type-aliases": "error",
     "anti-slop/no-unsafe-dictionary-type": "error",
     "anti-slop/no-widen-then-assert": "error",
     "anti-slop/require-safety-comment-for-type-assertion": "error"
   }
   ```

5. Run the repository's lint command and typecheck. For Vite+, run the repository's full `vp check` command after adding both lint and format ignores. If findings appear in owned project source, report them and fix them only when the user asked for migration/cleanup. Do not suppress rules, weaken rule severity, add unsafe casts, or mechanically launder types to make lint pass.

6. Review the final diff and clearly report:
   - copied path,
   - dependency versions installed,
   - configuration changed,
   - checks run and any remaining findings.

## ESLint and Prettier procedure

1. Inspect the repository before changing it, as in step 1 above, but look for ESLint configuration (`eslint.config.*`, or a legacy `.eslintrc*` that must be migrated to flat config first) and Prettier configuration (`.prettierrc*`, `prettier.config.*`, `.prettierignore`).

2. Copy the bundled plugin. Run from the target repository:

   ```bash
   node <skill-directory>/scripts/install.mjs --flavor eslint
   ```

   This creates `tools/eslint/anti-slop/`. Pass another relative destination after the flavor when the repository has an established tooling layout. The script refuses to replace an existing destination; only use `--force` after backing up and reviewing existing files.

3. Install current compatible development dependencies rather than trusting versions remembered by the agent:
   - `eslint`, `@typescript-eslint/parser`, and `@typescript-eslint/utils` (the copied source imports its types).
   - `jiti`, which ESLint requires to load a TypeScript flat config and the TypeScript plugin files it imports.
   - `eslint-config-prettier` when the repository uses Prettier.
   - Query `npm view <package> version` for each, and keep both `@typescript-eslint/*` packages on the same version.

   **TypeScript 7 check.** typescript-eslint throws `typescript-eslint does not support TS 7.0.` when it loads against the TypeScript 7 API. If the repository is on TypeScript 7, install the TypeScript 6 API side by side and keep TypeScript 7 for typechecking:

   ```json
   {
     "devDependencies": {
       "@typescript/native": "npm:typescript@7.0.2",
       "typescript": "npm:@typescript/typescript6@6.0.2"
     }
   }
   ```

   `tsc` still runs TypeScript 7, and tools that import the `typescript` package resolve the 6.0 API. Verify the pinned versions with `npm view` before writing them.

4. Register the plugin, configure ignores, and enable all rules. Merge these fields into the existing flat config, keeping every existing entry:

   ```ts
   import tsParser from "@typescript-eslint/parser";
   import prettier from "eslint-config-prettier";

   import antiSlop from "./tools/eslint/anti-slop/index.ts";

   export default [
     {
       ignores: [
         ".agent/**",
         ".agents/**",
         ".claude/**",
         ".codex/**",
         ".continue/**",
         ".cursor/**",
         ".gemini/**",
         ".opencode/**",
         ".pi/**",
         ".roo/**",
         ".windsurf/**",
         "tools/eslint/anti-slop/**",
       ],
     },
     {
       files: ["**/*.ts", "**/*.tsx", "**/*.mts", "**/*.cts"],
       languageOptions: {
         parser: tsParser,
         parserOptions: { ecmaVersion: "latest", sourceType: "module" },
       },
       plugins: { "anti-slop": antiSlop },
       rules: {
         "anti-slop/no-chained-type-assertions": "error",
         "anti-slop/no-conditional-empty-object-spread": "error",
         "anti-slop/no-known-value-widening": "error",
         "anti-slop/no-module-mocking": "error",
         "anti-slop/no-object-parameters": "error",
         "anti-slop/no-reflect-apply": "error",
         "anti-slop/no-reflect-get": "error",
         "anti-slop/no-runtime-typeof": "error",
         "anti-slop/no-shape-in-symbol-names": "error",
         "anti-slop/no-unknown-parameters": "error",
         "anti-slop/no-unknown-returns": "error",
         "anti-slop/no-unknown-type-aliases": "error",
         "anti-slop/no-unsafe-dictionary-type": "error",
         "anti-slop/no-widen-then-assert": "error",
         "anti-slop/require-safety-comment-for-type-assertion": "error",
       },
     },
     prettier,
   ];
   ```

   `antiSlop.configs.recommended` enables the same fifteen rules if the repository prefers a preset over an explicit rule list. Adjust the plugin path and the matching ignore entry when the plugin was copied elsewhere. Inspect the repository for other project-local agent tooling directories and add them rather than linting installed skills, hooks, or generated agent configuration as application source. Do not broadly ignore all dot-directories.

   The config file must be `eslint.config.ts` (or import the plugin from a `.ts` file) because the vendored plugin is TypeScript. A JavaScript `eslint.config.js` works too as long as `jiti` is installed and the import points at the `.ts` entry.

5. Configure Prettier, when the repository uses it. No anti-slop rule is stylistic, so nothing in this plugin conflicts with Prettier's output; the integration is only about ownership of files and rule ordering:
   - Keep `eslint-config-prettier` last in the flat config array, as above, so any other stylistic ESLint rules stay disabled.
   - Add the same agent tooling directories and the vendored plugin path to `.prettierignore`, so Prettier does not reformat installed agent assets or the copied rules.
   - Do not add formatting rules to ESLint to replace Prettier, and do not reformat the repository as part of this install.

6. Run the repository's lint command, its formatter check, and its typecheck. If findings appear in owned project source, report them and fix them only when the user asked for migration or cleanup. Do not suppress rules, weaken rule severity, add unsafe casts, or mechanically launder types to make lint pass.

7. Review the final diff and clearly report:
   - copied path,
   - dependency versions installed,
   - configuration changed,
   - checks run and any remaining findings.

## Migration guidance

When replacing an older local copy, compare its rules and diagnostics before overwriting. Keep project-specific rules in their own plugin; anti-slop is intentionally generic. Prefer inference, `as const`, `satisfies`, named owner contracts, and boundary parsing when resolving findings.
