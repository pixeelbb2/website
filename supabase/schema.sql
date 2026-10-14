-- PIXEELBB2 visitor counter backend (Supabase).
-- Run in Dashboard → SQL Editor → New query → paste → Run.
-- Safe to re-run any time: it never resets counters (site_stats untouched,
-- visit_log only gains rows).
--
-- Model: server-side fingerprint counting. The browser holds NO identity
-- token, so deploys / cache-busts / storage quirks cannot inflate uniques.
-- Uniqueness = first-seen SHA-256(IP + User-Agent + pepper). Only the hash
-- is stored — never raw IPs, no timestamps beyond first-seen. All-time ever.

create extension if not exists pgcrypto;

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

create sequence if not exists visit_log_seq;
-- If a visit_log table from an older experiment already exists (different
-- shape), drop it first — it was never written to by any live code:
--   drop table if exists visit_log;
create table if not exists visit_log (
  fp_hash text primary key,
  seq bigint not null default nextval('visit_log_seq'),
  first_seen timestamptz not null default now()
);
alter table visit_log enable row level security;
-- Deliberately NO policies on visit_log: anon cannot read it at all.
-- Only register_hit() (security definer) touches it.

create or replace function register_hit() returns jsonb
language plpgsql security definer set search_path = public as $$
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

-- Legacy per-browser RPCs stay granted so older cached pages keep working
-- during the transition (they only read once their token exists; fresh
-- draws stop as pages refresh). Definitions in git history.
--   bump_visits() / bump_hits()
