-- PVG dashboard foundation. Published with retired Google-account access disabled.
-- No public table reads, no broad authenticated grants and no auth configuration changes.
begin;

create schema if not exists pvg_private;
revoke all on schema pvg_private from public, anon, authenticated;

create or replace function pvg_private.is_dashboard_admin()
returns boolean language sql stable security definer set search_path = ''
as $$
  select false; -- Retired account-based access is deliberately disabled.
$$;
revoke all on function pvg_private.is_dashboard_admin() from public, anon, authenticated;

create table if not exists pvg_private.enquiry_status_history (
  id bigint generated always as identity primary key,
  enquiry_id uuid not null references public.pvg_ev_charging_requests(id),
  changed_by uuid references auth.users(id) on delete set null,
  previous_status text not null,
  new_status text not null,
  changed_at timestamptz not null default now()
);
alter table pvg_private.enquiry_status_history enable row level security;
revoke all on pvg_private.enquiry_status_history from public, anon, authenticated;

create or replace function public.pvg_dashboard_list(
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
  if not pvg_private.is_dashboard_admin() then
    raise exception 'Private PVG access is required' using errcode = 'PT403';
  end if;
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

create or replace function public.pvg_dashboard_update_status(
  p_id uuid, p_status text, p_expected_updated_at timestamptz
) returns jsonb language plpgsql security definer set search_path = ''
as $$
declare current_record public.pvg_ev_charging_requests%rowtype;
  saved_at timestamptz;
begin
  if not pvg_private.is_dashboard_admin() then
    raise exception 'Private PVG access is required' using errcode = 'PT403';
  end if;
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
  insert into pvg_private.enquiry_status_history(enquiry_id,changed_by,previous_status,new_status)
    values(p_id,auth.uid(),current_record.status,p_status);
  return jsonb_build_object('saved',true,'status',p_status,'updated_at',saved_at);
end;
$$;

revoke all on function public.pvg_dashboard_list(text,text,text,timestamptz,integer,integer) from public, anon, authenticated;
revoke all on function public.pvg_dashboard_update_status(uuid,text,timestamptz) from public, anon, authenticated;
-- These retired endpoints have no public execute grant. Apply the username migration next.
-- Existing table RLS/grants and the anonymous form submission function are untouched.
notify pgrst, 'reload schema';
commit;
