# Contributing to Scribe

## Branching — trunk-based

- **`main`** is always releasable. Don't commit directly to it for anything
  non-trivial.
- Work on **short-lived feature branches** cut from `main`, and open a PR back
  into `main`. Keep branches small and merge often.
- **Branch naming:** `<type>/<short-kebab-description>`, where `<type>` matches a
  commit type below.

  ```
  feat/document-sharing
  fix/autosave-race
  chore/eslint-config
  docs/readme-setup
  ```

## Commits — Conventional Commits

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(optional scope): <short summary>

[optional body]

[optional footer(s)]
```

**Types used in this project:**

| Type       | Use for                                                 |
| ---------- | ------------------------------------------------------- |
| `feat`     | A new user-facing feature                               |
| `fix`      | A bug fix                                               |
| `docs`     | Documentation only                                      |
| `style`    | Formatting only (no logic change)                       |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `test`     | Adding or fixing tests                                  |
| `chore`    | Tooling, config, deps, scaffolding                      |
| `perf`     | A performance improvement                               |
| `ci`       | CI configuration                                        |

**Examples:**

```
feat(share): let owners grant view or edit access by email
fix(editor): debounce autosave so rapid edits don't thrash the DB
chore: configure prettier + eslint-config-prettier
```

Breaking changes: add `!` after the type/scope (`feat!:`) or a `BREAKING CHANGE:`
footer.

## Enforcement (automatic)

Hooks are installed by `npm install` (Husky `prepare` script):

- **commit-msg** → `commitlint` rejects messages that aren't Conventional Commits.
- **pre-commit** → `lint-staged` runs ESLint (autofix) and Prettier on staged files.

If a hook blocks you, fix the message or the lint/format issue and recommit.

## Before opening a PR

```bash
npm run lint
npm run typecheck
npm run format:check
npm run build
```

All four should pass green.
