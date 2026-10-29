-- 0001_init.sql
-- Scribe initial schema: profiles, documents, document_shares.
--
-- Authorization is enforced HERE, at the database layer, per ADR-001. The RLS
-- policies below implement the access truth table 1:1. SECURITY DEFINER helper
-- functions perform the owner / share membership checks so the documents and
-- document_shares policies don't recurse into each other's RLS.
--
-- gen_random_uuid() is available in core Postgres (and pgcrypto is pre-enabled
-- on Supabase), so no CREATE EXTENSION is required.

-- ===========================================================================
-- profiles  — public mirror of auth.users; an email directory for sharing
-- ===========================================================================
create table public.profiles (
  id    uuid primary key references auth.users (id) on delete cascade,
  email text not null unique
); 

comment on table public.profiles is
  'Public mirror of auth.users; lets the app resolve a share recipient by email.';

-- Mirror every new auth user into profiles (and keep email current).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do update set email = excluded.email;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ===========================================================================
-- documents
-- ===========================================================================
create table public.documents (
  id         uuid        primary key default gen_random_uuid(),
  owner_id   uuid        not null references auth.users (id) on delete cascade,
  title      text        not null default 'Untitled',
  content    jsonb       not null default '{}'::jsonb,  -- Tiptap (ProseMirror) JSON
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on column public.documents.content is 'Tiptap (ProseMirror) document JSON.';

-- "My documents" list + ownership checks.
create index documents_owner_id_idx on public.documents (owner_id);

-- Keep updated_at fresh on every write.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger documents_set_updated_at
  before update on public.documents
  for each row execute function public.set_updated_at();

-- owner_id is immutable. An edit-share may change title/content but must never
-- seize ownership; this closes the escalation path called out in the truth table.
create or replace function public.prevent_owner_change()
returns trigger
language plpgsql
as $$
begin
  if new.owner_id is distinct from old.owner_id then
    raise exception 'owner_id is immutable';
  end if;
  return new;
end;
$$;

create trigger documents_prevent_owner_change
  before update on public.documents
  for each row execute function public.prevent_owner_change();

-- ===========================================================================
-- document_shares
-- ===========================================================================
create table public.document_shares (
  id                  uuid        primary key default gen_random_uuid(),
  document_id         uuid        not null references public.documents (id) on delete cascade,
  shared_with_user_id uuid        not null references auth.users (id)       on delete cascade,
  role                text        not null check (role in ('view', 'edit')),
  created_at          timestamptz not null default now(),
  unique (document_id, shared_with_user_id)   -- a doc can be shared with a user at most once
);

-- "Shared with me" + the per-user grant lookup RLS runs on every documents read.
create index document_shares_shared_with_user_id_idx
  on public.document_shares (shared_with_user_id);
-- No separate document_id index: the UNIQUE (document_id, shared_with_user_id)
-- btree already serves document_id-leading lookups.

-- ===========================================================================
-- Authorization helpers (SECURITY DEFINER: bypass RLS internally to avoid
-- documents <-> document_shares policy recursion; search_path pinned empty)
-- ===========================================================================
create or replace function public.is_document_owner(doc_id uuid)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select exists (
    select 1 from public.documents d
    where d.id = doc_id and d.owner_id = (select auth.uid())
  );
$$;

create or replace function public.document_share_role(doc_id uuid)
returns text
language sql
security definer
set search_path = ''
stable
as $$
  select s.role
  from public.document_shares s
  where s.document_id = doc_id
    and s.shared_with_user_id = (select auth.uid())
  limit 1;
$$;

revoke execute on function public.is_document_owner(uuid)   from public;
revoke execute on function public.document_share_role(uuid) from public;
grant  execute on function public.is_document_owner(uuid)   to authenticated;
grant  execute on function public.document_share_role(uuid) to authenticated;

-- ===========================================================================
-- Row-Level Security
-- ===========================================================================
alter table public.profiles        enable row level security;
alter table public.documents       enable row level security;
alter table public.document_shares enable row level security;

-- FORCE so even the table owner is subject to policies (defense in depth).
alter table public.profiles        force row level security;
alter table public.documents       force row level security;
alter table public.document_shares force row level security;

-- --- profiles: any authenticated user may read the directory (id + email) ---
create policy "profiles: readable by authenticated"
  on public.profiles for select
  to authenticated
  using ((select auth.uid()) is not null);

-- --- documents ---
-- SELECT: owner, or anyone it is shared with (view or edit).
create policy "documents: select own or shared"
  on public.documents for select
  to authenticated
  using (
    owner_id = (select auth.uid())
    or public.document_share_role(id) is not null
  );

-- INSERT: you may only create documents you own.
create policy "documents: insert own"
  on public.documents for insert
  to authenticated
  with check (owner_id = (select auth.uid()));

-- UPDATE: owner, or an edit-share. (owner_id immutability enforced by trigger.)
create policy "documents: update own or edit-shared"
  on public.documents for update
  to authenticated
  using (
    owner_id = (select auth.uid())
    or public.document_share_role(id) = 'edit'
  )
  with check (
    owner_id = (select auth.uid())
    or public.document_share_role(id) = 'edit'
  );

-- DELETE: owner only.
create policy "documents: delete own"
  on public.documents for delete
  to authenticated
  using (owner_id = (select auth.uid()));

-- --- document_shares ---
-- SELECT: document owner (manages shares) or the recipient (lists "shared with me").
create policy "shares: select as owner or recipient"
  on public.document_shares for select
  to authenticated
  using (
    public.is_document_owner(document_id)
    or shared_with_user_id = (select auth.uid())
  );

-- INSERT / UPDATE / DELETE: only the document owner may share, re-role, or revoke.
create policy "shares: insert by document owner"
  on public.document_shares for insert
  to authenticated
  with check (public.is_document_owner(document_id));

create policy "shares: update by document owner"
  on public.document_shares for update
  to authenticated
  using (public.is_document_owner(document_id))
  with check (public.is_document_owner(document_id));

create policy "shares: delete by document owner"
  on public.document_shares for delete
  to authenticated
  using (public.is_document_owner(document_id));

-- ===========================================================================
-- Grants (RLS gates which rows; table privileges gate the operation at all)
-- ===========================================================================
grant select                         on public.profiles        to authenticated;
grant select, insert, update, delete on public.documents       to authenticated;
grant select, insert, update, delete on public.document_shares to authenticated;
