# Scribe

A lightweight shared document editor. Create, rename, edit, and reopen rich-text
documents with basic formatting, import a text file into a new document, and
share a document with another user at **view** or **edit** access.

Built with **Next.js (App Router) + TypeScript + Tailwind CSS**, with
**Supabase** for Postgres, Auth, and Storage. Document content is persisted as
Tiptap (ProseMirror) JSON.

> Scope, non-goals, and the data-model / authorization design are in
> [`docs/scope.md`](docs/scope.md). This is a demo-scale build and deliberately
> not real-time collaborative — see the scope doc.

## Prerequisites

- **Node.js >= 20** (a `.nvmrc` pins 22; run `nvm use` if you use nvm)
- **npm** (project uses `package-lock.json`)
- A **Supabase** project (free tier is fine) for the database

## Setup

```bash
# 1. Install dependencies (also wires up the git hooks via "prepare")
npm install

# 2. Configure environment
cp .env.example .env.local
# then edit .env.local with your Supabase URL + keys (never commit .env.local)
```

### Database

Apply the initial schema in `supabase/migrations/0001_init.sql` to your Supabase
project. Either paste it into the Supabase SQL editor, or with the Supabase CLI:

```bash
supabase link --project-ref <your-project-ref>
supabase db push
```

The migration creates `profiles`, `documents`, and `document_shares`, enables
Row-Level Security, and installs policies that enforce the sharing model (owner
full control; `view` = read-only; `edit` = read + write content; non-recipients
get nothing). `owner_id` is immutable by trigger.

## Run

```bash
npm run dev     # start the dev server (http://localhost:3000)
npm run build   # production build
npm run start   # serve the production build
```

## Scripts

| Script                 | What it does                         |
| ---------------------- | ------------------------------------ |
| `npm run dev`          | Start the Next.js dev server         |
| `npm run build`        | Production build                     |
| `npm run start`        | Serve the production build           |
| `npm run lint`         | ESLint                               |
| `npm run lint:fix`     | ESLint with autofix                  |
| `npm run typecheck`    | TypeScript, no emit (`tsc --noEmit`) |
| `npm run format`       | Prettier write across the repo       |
| `npm run format:check` | Prettier check (CI-safe, no writes)  |

## Project structure

```
src/app/            App Router routes, layouts, pages
supabase/migrations/ SQL migrations (0001_init.sql = initial schema + RLS)
docs/               Project docs (scope.md)
```

## Conventions

Branching and commit conventions are documented in
[`CONTRIBUTING.md`](CONTRIBUTING.md) and enforced by Husky + commitlint +
lint-staged on commit.
