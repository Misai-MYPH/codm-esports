-- Community Gladiators registration MVP. Apply in Supabase SQL editor before enabling the page.
-- Existing CODM Tournament OS tables are left untouched.
create extension if not exists pgcrypto;
create table if not exists public.cg_registrations (
 id uuid primary key default gen_random_uuid(),
 tournament_slug text not null,
 applicant_id uuid not null references auth.users(id),
 division text not null check (division in ('battle_royale_solo','battle_royale_squads','multiplayer_1v1','multiplayer_5v5')),
 region text not null check(region in ('PH','MYSG')),
 representative_name text not null,
 representative_email text not null,
 discord_username text not null,
 discord_user_id text,
 messenger_url text,
 whatsapp_number text,
 team_name text,
 team_tag text,
 team_logo_url text,
 status text not null default 'pending' check(status in ('pending','approved','waitlisted','rejected')),
 rulebook_accepted_at timestamptz not null,
 accuracy_confirmed_at timestamptz not null,
 created_at timestamptz not null default now(),
 unique(tournament_slug,applicant_id,division)
);
create table if not exists public.cg_registration_players (
 id uuid primary key default gen_random_uuid(),
 registration_id uuid not null references public.cg_registrations(id) on delete cascade,
 tournament_slug text not null,
 division text not null,
 slot integer not null check(slot between 1 and 5),
 full_name text not null,
 ign text not null,
 uid text not null,
 open_id text not null,
 created_at timestamptz not null default now(),
 unique(registration_id,slot),
 unique(tournament_slug,division,uid),
 unique(tournament_slug,division,open_id)
);
create index if not exists cg_registrations_tournament_status_idx on public.cg_registrations(tournament_slug,status);
alter table public.cg_registrations enable row level security;
alter table public.cg_registration_players enable row level security;
revoke all on public.cg_registrations from anon,authenticated;
revoke all on public.cg_registration_players from anon,authenticated;
grant select on public.cg_registrations to authenticated;
grant select on public.cg_registration_players to authenticated;
drop policy if exists cg_registrations_self_read on public.cg_registrations;
create policy cg_registrations_self_read on public.cg_registrations for select to authenticated using(applicant_id=auth.uid());
drop policy if exists cg_players_self_read on public.cg_registration_players;
create policy cg_players_self_read on public.cg_registration_players for select to authenticated using(exists(select 1 from public.cg_registrations r where r.id=registration_id and r.applicant_id=auth.uid()));

create or replace function public.submit_cg_registration(payload jsonb)
returns uuid language plpgsql security definer set search_path = public, pg_temp as $$
declare
 v_user uuid := auth.uid();
 v_id uuid;
 v_division text := payload->>'division';
 v_region text := payload->>'region';
 v_slug text := payload->>'tournament_slug';
 v_email text;
 v_count int;
 v_expected int;
 v_player jsonb;
 v_slot int := 0;
begin
 if v_user is null then raise exception 'Please sign in first'; end if;
 select lower(email) into v_email from auth.users where id=v_user;
 if v_email is distinct from lower(trim(payload->>'representative_email')) then raise exception 'Email does not match signed-in account'; end if;
 if v_slug is null or v_slug !~ '^[a-z0-9][a-z0-9-]{2,99}$' then raise exception 'Invalid tournament slug'; end if;
 if v_division not in ('battle_royale_solo','battle_royale_squads','multiplayer_1v1','multiplayer_5v5') or v_division is null then raise exception 'Invalid division'; end if;
 if v_region not in ('PH','MYSG') or v_region is null then raise exception 'Invalid region'; end if;
 if coalesce(payload->>'representative_name','')='' or length(payload->>'representative_name')>120 then raise exception 'Invalid representative name'; end if;
 if coalesce(payload->>'discord_username','')='' or length(payload->>'discord_username')>80 then raise exception 'Discord username required'; end if;
 if v_region='PH' and coalesce(payload->>'messenger_url','') !~ '^https://(www\.)?(facebook\.com|m\.facebook\.com|messenger\.com|m\.me)/' then raise exception 'Valid Messenger profile link required'; end if;
 if v_region='MYSG' and coalesce(payload->>'whatsapp_number','') !~ '^\+?[0-9 ()-]{8,24}$' then raise exception 'Valid WhatsApp number required'; end if;
 if payload->>'rulebook_accepted' <> 'true' or payload->>'accuracy_confirmed' <> 'true' then raise exception 'Declarations required'; end if;
 v_expected := case v_division when 'battle_royale_squads' then 4 when 'multiplayer_5v5' then 5 else 1 end;
 if jsonb_typeof(payload->'players') is distinct from 'array' then raise exception 'Players must be an array'; end if;
 v_count:=jsonb_array_length(payload->'players');
 if v_count<>v_expected then raise exception 'Expected % players',v_expected; end if;
 if v_expected>1 and (coalesce(trim(payload->>'team_name'),'')='' or coalesce(trim(payload->>'team_tag'),'')='') then raise exception 'Team name and tag required'; end if;
 if length(coalesce(payload->>'team_name',''))>100 or length(coalesce(payload->>'team_tag',''))>16 then raise exception 'Team name or tag too long'; end if;
 for v_player in select value from jsonb_array_elements(payload->'players') loop
  if coalesce(trim(v_player->>'name'),'')='' or coalesce(trim(v_player->>'ign'),'')='' or coalesce(trim(v_player->>'uid'),'')='' or coalesce(trim(v_player->>'open_id'),'')='' then raise exception 'All player fields are required'; end if;
  if length(v_player->>'name')>120 or length(v_player->>'ign')>120 or length(v_player->>'uid')>120 or length(v_player->>'open_id')>120 then raise exception 'Player field too long'; end if;
 end loop;
 insert into public.cg_registrations(tournament_slug,applicant_id,division,region,representative_name,representative_email,discord_username,messenger_url,whatsapp_number,team_name,team_tag,team_logo_url,rulebook_accepted_at,accuracy_confirmed_at)
 values(v_slug,v_user,v_division,v_region,trim(payload->>'representative_name'),v_email,trim(payload->>'discord_username'),nullif(trim(payload->>'messenger_url'),''),nullif(trim(payload->>'whatsapp_number'),''),nullif(trim(payload->>'team_name'),''),nullif(trim(payload->>'team_tag'),''),nullif(trim(payload->>'team_logo_url'),''),now(),now()) returning id into v_id;
 for v_player in select value from jsonb_array_elements(payload->'players') loop
  v_slot:=v_slot+1;
  insert into public.cg_registration_players(registration_id,tournament_slug,division,slot,full_name,ign,uid,open_id)
  values(v_id,v_slug,v_division,v_slot,trim(v_player->>'name'),trim(v_player->>'ign'),trim(v_player->>'uid'),trim(v_player->>'open_id'));
 end loop;
 return v_id;
exception when unique_violation then
 raise exception 'This account or a player ID is already registered in this division';
end $$;
revoke all on function public.submit_cg_registration(jsonb) from public,anon;
grant execute on function public.submit_cg_registration(jsonb) to authenticated;
