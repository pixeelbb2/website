-- PIXEELBB2 visitor counter (Supabase). Safe to re-run: nothing is reset.
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
create table if not exists visit_log (
  fp_hash text primary key,
  seq bigint not null default nextval('visit_log_seq'),
  first_seen timestamptz not null default now(),
  ua text
);
alter table visit_log add column if not exists ua text;
alter table visit_log enable row level security;

create or replace function register_hit() returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  hdrs jsonb; ipf text; ua text; fp text;
  myseq bigint; v bigint; h bigint;
begin
  hdrs := coalesce(nullif(current_setting('request.headers', true), '')::jsonb, '{}'::jsonb);
  ipf := split_part(coalesce(hdrs->>'x-forwarded-for', hdrs->>'x-real-ip', hdrs->>'cf-connecting-ip', 'unknown'), ',', 1);
  ua := coalesce(hdrs->>'user-agent', 'unknown');

  -- ignore bots: no insert, no counter change
  if ua ~* '(screenjesus|bot|crawl|spider|headless|puppeteer|playwright|selenium|lighthouse|curl|wget|python-requests|node-fetch|axios|go-http)' then
    select visits, hits into v, h from site_stats where id = 1;
    return jsonb_build_object('visitors', v, 'hits', h, 'my', null);
  end if;

  fp := encode(digest(ipf || '|' || ua || '|pixeel-pepper-7f3a9c', 'sha256'), 'hex');
  insert into visit_log(fp_hash, ua) values (fp, left(ua, 300))
  on conflict (fp_hash) do nothing
  returning seq into myseq;
  if myseq is null then
    select seq into myseq from visit_log where fp_hash = fp;
    update site_stats set hits = hits + 1 where id = 1 returning hits into h;
    select visits into v from site_stats where id = 1;
  else
    update site_stats set visits = visits + 1, hits = hits + 1 where id = 1
    returning visits, hits into v, h;
  end if;
  return jsonb_build_object('visitors', v, 'hits', h, 'my', myseq);
end $$;
grant execute on function register_hit() to anon;

create or replace function peek_stats() returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  hdrs jsonb; ipf text; ua text; fp text;
  myseq bigint; v bigint; h bigint;
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

-- Legacy RPCs (kept so old cached pages don't error)
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

-- RESET (DESTRUCTIVE). Keep commented out. Uncomment for one run only.
-- update site_stats set visits = 0, hits = 0 where id = 1;
-- truncate visit_log;
-- alter sequence visit_log_seq restart with 1;
