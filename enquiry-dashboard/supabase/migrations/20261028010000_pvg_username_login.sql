-- Separate PVG credentials and opaque sessions. No auth.users/provider changes.
-- Credentials are provisioned separately; no password or hash in source control.
begin;
create table if not exists pvg_private.dashboard_credentials (
  username text primary key check (username = 'admin'),
  password_hash text not null,
  credential_version uuid not null default gen_random_uuid(),
  failed_attempts integer not null default 0,
  locked_until timestamptz,
  updated_at timestamptz not null default now()
);
create table if not exists pvg_private.dashboard_sessions (
  token_hash bytea primary key,
  username text not null references pvg_private.dashboard_credentials(username),
  credential_version uuid not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null
);
alter table pvg_private.dashboard_credentials enable row level security;
alter table pvg_private.dashboard_sessions enable row level security;
revoke all on pvg_private.dashboard_credentials,pvg_private.dashboard_sessions from public,anon,authenticated;
alter table pvg_private.enquiry_status_history add column if not exists actor_label text;

create or replace function public.pvg_dashboard_login(p_username text,p_password text)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare account pvg_private.dashboard_credentials%rowtype; token text; failed integer;
begin
  select * into account from pvg_private.dashboard_credentials where username='admin' for update;
  if not found then return jsonb_build_object('ok',false,'error','unavailable'); end if;
  if account.locked_until > clock_timestamp() then
    return jsonb_build_object('ok',false,'error','rate_limited','retry_after',greatest(1,ceil(extract(epoch from account.locked_until-clock_timestamp())))::integer);
  end if;
  if p_username is null or p_username <> account.username or p_password is null
     or octet_length(p_password) not between 1 and 72
     or extensions.crypt(p_password,account.password_hash) is distinct from account.password_hash then
    failed := case when account.locked_until is not null then 1 else account.failed_attempts+1 end;
    update pvg_private.dashboard_credentials set failed_attempts=failed,
      locked_until=case when failed>=5 then clock_timestamp()+interval '15 minutes' else null end
      where username='admin';
    -- Return, rather than raise, so failed-attempt accounting commits.
    return jsonb_build_object('ok',false,'error',case when failed>=5 then 'rate_limited' else 'invalid_login' end,'retry_after',case when failed>=5 then 900 else 0 end);
  end if;
  update pvg_private.dashboard_credentials set failed_attempts=0,locked_until=null where username='admin';
  delete from pvg_private.dashboard_sessions where expires_at <= clock_timestamp() or credential_version<>account.credential_version;
  token := encode(extensions.gen_random_bytes(32),'hex');
  insert into pvg_private.dashboard_sessions(token_hash,username,credential_version,expires_at)
    values(extensions.digest(token,'sha256'),account.username,account.credential_version,clock_timestamp()+interval '1 hour');
  return jsonb_build_object('ok',true,'session_token',token,'expires_in',3600);
end;
$$;

create or replace function pvg_private.require_dashboard_session(p_session_token text)
returns void language plpgsql security definer set search_path = ''
as $$
begin
  if p_session_token is null or p_session_token !~ '^[0-9a-f]{64}$' or not exists (
    select 1 from pvg_private.dashboard_sessions s
    join pvg_private.dashboard_credentials c on c.username=s.username and c.credential_version=s.credential_version
    where s.token_hash=extensions.digest(p_session_token,'sha256') and s.expires_at>clock_timestamp()
  ) then raise exception 'Please sign in to the PVG dashboard' using errcode='PT401'; end if;
end;
$$;

create or replace function public.pvg_dashboard_logout(p_session_token text)
returns jsonb language plpgsql security definer set search_path = ''
as $$
begin
  if p_session_token ~ '^[0-9a-f]{64}$' then
    delete from pvg_private.dashboard_sessions where token_hash=extensions.digest(p_session_token,'sha256');
  end if;
  return jsonb_build_object('ok',true);
end;
$$;

create or replace function pvg_private.dashboard_list(
  p_search text default '',
  p_type text default 'all',
  p_status text default 'all',
  p_since timestamptz default null,
  p_offset integer default 0,
  p_limit integer default 20
) returns jsonb language plpgsql security definer set search_path = ''
as $$
declare result jsonb;
begin
  if p_type is null or p_type not in ('all','request','fleet','contact','pilot')
    or p_status is null or p_status not in ('all','new','active','reviewing','contacted','closed','spam')
    or p_limit is null or p_limit not between 1 and 50
    or p_offset is null or p_offset not between 0 and 10000000
    or length(coalesce(p_search,'')) > 120 then
    raise exception 'Invalid filters' using errcode = '22023';
  end if;
  with enquiries as materialized (
    select * from public.pvg_ev_charging_requests where source = 'pvg_ev_website'
  ), filtered as materialized (
    select * from enquiries r
    where (p_type = 'all' or r.form_type = p_type)
      and (p_status = 'all' or r.status = p_status or (p_status = 'active' and r.status in ('reviewing','contacted')))
      and (p_since is null or r.created_at >= p_since)
      and (btrim(coalesce(p_search,'')) = '' or
        strpos(lower(concat_ws(' ',r.name,r.phone,r.email,r.company,r.reference,r.city,r.requirement_type)), lower(btrim(p_search))) > 0)
  ), paged as (
    select * from filtered order by created_at desc,id desc limit p_limit offset p_offset
  )
  select jsonb_build_object(
    'records', coalesce((select jsonb_agg(to_jsonb(p) order by p.created_at desc,p.id desc) from paged p),'[]'::jsonb),
    'total', (select count(*) from filtered),
    'stats', (select jsonb_build_object(
      'total', count(*), 'new',count(*) filter (where status='new'),
      'active',count(*) filter (where status in ('reviewing','contacted')),
      'closed',count(*) filter (where status='closed')
    ) from enquiries)
  ) into result;
  return result;
end;
$$;

create or replace function pvg_private.dashboard_update_status(
  p_id uuid, p_status text, p_expected_updated_at timestamptz
) returns jsonb language plpgsql security definer set search_path = ''
as $$
declare current_record public.pvg_ev_charging_requests%rowtype;
  saved_at timestamptz;
begin
  if p_status is null or p_status not in ('new','reviewing','contacted','closed','spam')
     or p_expected_updated_at is null then
    raise exception 'Invalid status change' using errcode = '22023';
  end if;
  select * into current_record from public.pvg_ev_charging_requests
    where id=p_id and source='pvg_ev_website' for update;
  if not found then raise exception 'Enquiry not found' using errcode = 'PT404'; end if;
  if current_record.updated_at is distinct from p_expected_updated_at then
    raise exception 'Enquiry changed; refresh before saving' using errcode = 'PT409';
  end if;
  if current_record.status = p_status then
    return jsonb_build_object('saved',true,'status',p_status,'updated_at',current_record.updated_at);
  end if;
  update public.pvg_ev_charging_requests set status=p_status where id=p_id returning updated_at into saved_at;
  insert into pvg_private.enquiry_status_history(enquiry_id,changed_by,previous_status,new_status,actor_label)
    values(p_id,null,current_record.status,p_status,'PVG admin');
  return jsonb_build_object('saved',true,'status',p_status,'updated_at',saved_at);
end;
$$;


create or replace function public.pvg_dashboard_session_list(
  p_session_token text,p_search text default '',p_type text default 'all',p_status text default 'all',
  p_since timestamptz default null,p_offset integer default 0,p_limit integer default 20
) returns jsonb language plpgsql security definer set search_path = ''
as $$
begin
  perform pvg_private.require_dashboard_session(p_session_token);
  return pvg_private.dashboard_list(p_search,p_type,p_status,p_since,p_offset,p_limit);
end;
$$;

create or replace function public.pvg_dashboard_session_update_status(
  p_session_token text,p_id uuid,p_status text,p_expected_updated_at timestamptz
) returns jsonb language plpgsql security definer set search_path = ''
as $$
begin
  perform pvg_private.require_dashboard_session(p_session_token);
  return pvg_private.dashboard_update_status(p_id,p_status,p_expected_updated_at);
end;
$$;

revoke all on function pvg_private.require_dashboard_session(text) from public,anon,authenticated;
revoke all on function pvg_private.dashboard_list(text,text,text,timestamptz,integer,integer) from public,anon,authenticated;
revoke all on function pvg_private.dashboard_update_status(uuid,text,timestamptz) from public,anon,authenticated;
revoke all on function public.pvg_dashboard_login(text,text) from public,anon,authenticated;
revoke all on function public.pvg_dashboard_logout(text) from public,anon,authenticated;
revoke all on function public.pvg_dashboard_session_list(text,text,text,text,timestamptz,integer,integer) from public,anon,authenticated;
revoke all on function public.pvg_dashboard_session_update_status(text,uuid,text,timestamptz) from public,anon,authenticated;
grant execute on function public.pvg_dashboard_login(text,text),public.pvg_dashboard_logout(text),
  public.pvg_dashboard_session_list(text,text,text,text,timestamptz,integer,integer),
  public.pvg_dashboard_session_update_status(text,uuid,text,timestamptz) to anon,authenticated;

-- Retire only the PVG dashboard's former Google-account endpoints.
revoke all on function public.pvg_dashboard_list(text,text,text,timestamptz,integer,integer) from public,anon,authenticated;
revoke all on function public.pvg_dashboard_update_status(uuid,text,timestamptz) from public,anon,authenticated;
notify pgrst,'reload schema';
commit;
