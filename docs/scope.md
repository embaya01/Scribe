# Scribe — Scope Lock

**A lightweight shared document editor.**
This document is the contract the build is held to. Anything not listed in **In Scope** is, by default, **Out of Scope** for the timebox.

|                 |                                                                                                                                                                           |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Goal**        | Browser-based rich-text editor: create, rename, edit, reopen documents with basic formatting; import a text file into a new document; share a document with another user. |
| **Stack**       | Next.js (App Router) + React + TypeScript · Tiptap (ProseMirror) · Tailwind · Supabase (Postgres / Auth / Storage) · Vercel hosting. Content persisted as Tiptap JSON.    |
| **Scale**       | Demo scale — a handful of users, tens of documents, low concurrency.                                                                                                      |
| **Timebox**     | 4–6h hard cap, target ~5h. Ship the strongest working slice at the cap.                                                                                                   |
| **Constraints** | No paid dependencies or services anyone must purchase.                                                                                                                    |

> **Deliberate architectural decision, not an oversight:** Scribe is sized to the stated demo scale. It is **not** built for high concurrency or real-time multi-cursor editing. **"Collaborative" here means asynchronous shared access** — users share documents and open ones shared with them, but do **not** co-edit the same document live at the same time. The data model, save model, and sharing model are chosen to fit this scale on purpose. This is called out again under _Out of Scope_ and _Depth Bets_.

---

## 1. In Scope

### Authentication

- Supabase Auth, email/password.
- **2 seeded accounts** provisioned for the sharing demo.
- Sign in / sign out.

### Documents

- **Create** a new (empty) document.
- **Rename** a document.
- **Edit** document content in a rich-text surface (Tiptap).
- **Reopen** — list the user's documents and open any one.
- Content stored as **Tiptap JSON** in Postgres.
- **Autosave** (debounced) with a visible "saved" indicator. _(Explicit-save fallback if the timebox tightens.)_

### Formatting (the ceiling — nothing beyond this line is in scope)

- **Bold**, _italic_, underline.
- Headings **H1–H3**.
- **Bulleted** and **numbered** lists.

### Import

- Import a file **into a new document**, parsed to Tiptap JSON; the uploaded source file is **discarded after parsing**.
- Accepted types: **`.txt`, `.md`**.
- `.md` is parsed into real formatting (headings, emphasis, lists) within the formatting ceiling above.
- Upload is validated: **file-type allow-list** and a **size limit** enforced server-side before parsing.

### Sharing

- A document owner can **share a document with another user by email** (email must resolve to an existing user).
- **Access level is selectable per share: `view` or `edit`.**
- A recipient sees documents shared with them and gets exactly the access granted:
  - `view` → open and read, no edits persisted.
  - `edit` → open and edit.
- **Authorization is enforced at the database layer (Supabase RLS) and server-side**, not only in the UI. A user can only read/write documents they own or that are shared with them at the appropriate level.

---

## 2. Out of Scope

Explicitly **not** built in this slice (listed so the boundary reads as judgment, not omission):

- **Real-time collaborative editing** — multi-cursor, live presence, operational transforms / CRDTs. _(Deliberate — see header.)_
- **Self-service signup**, password reset, email verification, account management. _(Seeded accounts only.)_
- **Inviting a non-existent user by email** (share resolves only to existing users).
- Formatting beyond the listed set: links, images, tables, code blocks, colors, fonts, text alignment, blockquotes.
- **Export** / download of documents to any format.
- **Comments, suggestions, version history, trash/restore.**
- `.docx` import (any fidelity).
- Folders, tags, search, sorting beyond a basic document list.
- Mobile-optimized layout, offline support, PWA.
- Org/team/role management beyond per-document sharing.
- Rate limiting, abuse prevention, and production-grade observability beyond basic logging.

---

## 3. General Success Criteria

### Functional (reviewer click-through)

A reviewer can, end to end:

1. Sign in as seeded user **A**.
2. Create a document, rename it, type content, apply **B / I / U**, an **H1–H3**, and a **bulleted + numbered list**; see it **autosave**; reopen it and see the content intact.
3. Import a **`.txt`** and a **`.md`** file, each landing as a new document with formatting within the supported formatting set.
4. Share a document with seeded user **B** as **view**, and a second document as **edit**.
5. Sign in as **B**: see both shared documents; confirm the **view** one is read-only and the **edit** one is editable.
6. Confirm **B cannot access** a document that was never shared (no URL-guessing access).

### Non-functional

- **Authz correctness:** no cross-user read or write leakage; access matches the granted role. Enforced in RLS + server, verified by test.
- **Input validation:** upload type/size enforced server-side; parse handles malformed input without crashing; source file discarded after parse.
- **Secrets:** no secrets committed; service keys server-only; anon key scoped correctly.
- **Pipeline-ready:** lint, type-check, tests, and build all pass green.
- **Maintainability:** conventional structure, typed end to end, clear commits.

---

## 4. Depth Bets

The load-bearing assumptions. If one of these is wrong, the slice fails regardless of how polished everything else is. These are the two to watch.

### Bet 1 — The sharing model is correct **and** secure.

The headline feature is _selectable per-share view/edit access_. The bet is that this can be enforced at the **database layer (RLS) plus server-side**, such that:

- A recipient gets exactly the role granted, and nothing more.
- A non-recipient gets **nothing** — including via direct URL or API calls, not just a hidden button.
- `view` cannot be escalated to `edit` client-side.

If authorization lives only in the UI, or RLS lets a role leak, this is a security hole and the feature is worthless. **This bet is mitigated by making authz a first-class, test-covered requirement** (see Success Criteria), not a late add-on. _This is the single assumption most likely to sink the slice, so it is built and tested first-class._

### Bet 2 — The tests and docs convince the reviewer the model works.

The slice is being judged. The bet is that a reviewer can **verify the sharing model is safe without reading every line of code** — because tests demonstrate the authz boundaries (A shares, B gets the right access, B is denied A's unshared documents) and the docs state what was built, what was deliberately left out, and why. If the sharing model works but nothing proves it legibly, the slice does not land.

- **Mitigation:** ship authz/sharing tests as acceptance evidence, keep this scope doc and a short README current, and make the demo path above reproducible.

---

## 5. Stub List — If I Had 2–4 More Hours

Named but **not** committed to in this timebox:

- **Edit-share concurrency guard** — last-write-wins with a "this document changed" notice, since multiple editors are now possible but real-time is out of scope.
- **Lightweight presence** — "last edited by / at" indicator (not live cursors).
- **`.docx` import**, and richer `.md` import fidelity — links, tables, images.
- **Export** — download a document as `.md` or `.docx`.
- **Self-service signup + password reset.**
- **Invite a non-existent user by email** (pending-invite flow).
- **Document list quality-of-life** — search, sort, "shared with me" vs "owned" filter, folders/tags.
- **Revoke / change a share's access level** after it's granted.
- **Observability** — structured logging and basic metrics on the server routes.
- **Rate limiting** on upload and share endpoints.
