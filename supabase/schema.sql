-- PIXEELBB2 visitor counter backend (Supabase) — THE ONLY SQL FILE.
-- This replaces both old snippets (the bump_visits/bump_hits setup block
-- and the standalone reset line). Delete those; keep just this.
-- Run in Dashboard → SQL Editor → New query → paste whole file → Run.
-- Safe to re-run any time: sections 1-4 never reset anything (counters in
-- site_stats untouched, visit_log only gains rows). The ONLY destructive
-- part is section 5 (RESET), which ships commented out — uncomment it for
-- one run only when you truly want a fresh start, then re-comment.
--
-- Model: server-side fingerprint counting. The browser holds NO identity
-- token, so deploys / cache-busts / storage quirks cannot inflate uniques.
-- Uniqueness = first-seen SHA-256(IP + User-Agent + pepper). Only the hash
-- is stored — never raw IPs, no timestamps beyond first-seen. All-time ever.

-- ============ 1. EXTENSION ============
create extension if not exists pgcrypto;

-- ============ 2. COUNTERS (shared, preserved across re-runs) ============
create table if not exists site_stats (
  id int primary key,
  visits bigint not null default 0,
  hits bigint not null default 0
);
insert into site_stats (id, visits, hits) values (1, 0, 0)
on conflict (id) do nothing;
alter table site_stats enable row level security;
drop policy if exists "read all" on site_stats;
create policy "read all" on site_stats for select using (true);

-- ============ 3. FINGERPRINT LOG (all-time uniques) ============
create sequence if not exists visit_log_seq;
-- If a visit_log table from a pre-migration experiment already exists
-- (different shape), drop it first — it was never written to by live code:
--   drop table if exists visit_log;
-- (The old setup's `drop table if exists visit_log;` line is intentionally
-- NOT part of this file anymore — it would wipe the fingerprint log.)
create table if not exists visit_log (
  fp_hash text primary key,
  seq bigint not null default nextval('visit_log_seq'),
  first_seen timestamptz not null default now()
);
alter table visit_log enable row level security;
-- Deliberately NO policies on visit_log: anon cannot read it at all.
-- Only register_hit() (security definer) touches it.

-- ============ 4. HIT REGISTRAR (the only writer the page calls) ============
create or replace function register_hit() returns jsonb
-- search_path covers both extension layouts (older projects: public,
-- newer ones: extensions schema) so digest() always resolves.
language plpgsql security definer set search_path = public, extensions as $$
declare
  hdrs jsonb;
  ipf text;
  ua text;
  fp text;
  myseq bigint;
  v bigint;
  h bigint;
begin
  hdrs := coalesce(nullif(current_setting('request.headers', true), '')::jsonb, '{}'::jsonb);
  ipf := split_part(coalesce(hdrs->>'x-forwarded-for', hdrs->>'x-real-ip', hdrs->>'cf-connecting-ip', 'unknown'), ',', 1);
  ua := coalesce(hdrs->>'user-agent', 'unknown');
  fp := encode(digest(ipf || '|' || ua || '|pixeel-pepper-7f3a9c', 'sha256'), 'hex');
  insert into visit_log(fp_hash) values (fp)
  on conflict (fp_hash) do nothing
  returning seq into myseq;
  if myseq is null then
    -- Known fingerprint: pageview only.
    select seq into myseq from visit_log where fp_hash = fp;
    update site_stats set hits = hits + 1 where id = 1 returning hits into h;
    select visits into v from site_stats where id = 1;
  else
    -- New fingerprint: unique + pageview, atomically (concurrent
    -- first-sees collapse on the PK — uniques can't double-count).
    update site_stats set visits = visits + 1, hits = hits + 1 where id = 1
    returning visits, hits into v, h;
  end if;
  return jsonb_build_object('visitors', v, 'hits', h, 'my', myseq);
end $$;
grant execute on function register_hit() to anon;

-- Read-only twin: same fingerprint lookup, zero writes. The page calls
-- this on repeat loads within one tab session (refresh, back-nav) so
-- TOTAL moves once per session, never per load — while uniques stay
-- purely server-side and deploy-proof.
create or replace function peek_stats() returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  hdrs jsonb;
  ipf text;
  ua text;
  fp text;
  myseq bigint;
  v bigint;
  h bigint;
begin
  hdrs := coalesce(nullif(current_setting('request.headers', true), '')::jsonb, '{}'::jsonb);
  ipf := split_part(coalesce(hdrs->>'x-forwarded-for', hdrs->>'x-real-ip', hdrs->>'cf-connecting-ip', 'unknown'), ',', 1);
  ua := coalesce(hdrs->>'user-agent', 'unknown');
  fp := encode(digest(ipf || '|' || ua || '|pixeel-pepper-7f3a9c', 'sha256'), 'hex');
  select seq into myseq from visit_log where fp_hash = fp;
  select visits, hits into v, h from site_stats where id = 1;
  return jsonb_build_object('visitors', v, 'hits', h, 'my', myseq);
end $$;
grant execute on function peek_stats() to anon;

-- Legacy per-browser RPCs (kept defined + granted so older cached pages
-- keep working through the transition; fresh draws stop as pages refresh).
create or replace function bump_visits() returns bigint
language plpgsql security definer set search_path = public as $$
declare n bigint;
begin
  update site_stats set visits = visits + 1 where id = 1 returning visits into n;
  return n;
end $$;
grant execute on function bump_visits() to anon;

create or replace function bump_hits() returns bigint
language plpgsql security definer set search_path = public as $$
declare n bigint;
begin
  update site_stats set hits = hits + 1 where id = 1 returning hits into n;
  return n;
end $$;
grant execute on function bump_hits() to anon;

-- ============ 5. ONE-TIME FRESH-START RESET (COMMENTED OUT — READ FIRST) ============
-- To wipe everything and start clean at 0/0 (new sequence from #1):
--   1. Uncomment the three lines below,
--   2. Run this file ONCE,
--   3. Re-comment them immediately (never leave them live: EVERY re-run
--      with them active zeroes your counters AND re-deals all numbers).
-- NOTE: a reset re-deals everyone's personal number in arrival order —
-- backend resets can't preserve them, only the server sequence does.
-- update site_stats set visits = 0, hits = 0 where id = 1;
-- truncate visit_log;
-- alter sequence visit_log_seq restart with 1;
