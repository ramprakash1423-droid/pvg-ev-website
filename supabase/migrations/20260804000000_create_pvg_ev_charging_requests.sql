create extension if not exists pgcrypto;

create table if not exists public.pvg_ev_charging_requests (
  id uuid primary key default gen_random_uuid(),
  reference text not null unique,
  source text not null default 'pvg_ev_website',
  form_type text not null,
  requirement_type text,
  customer_type text,
  requirement_scope text,
  priority text,
  use_case text,
  phone text not null,
  name text,
  email text,
  company text,
  city text,
  location_type text,
  address text,
  gps_location text,
  latitude numeric(10, 6),
  longitude numeric(10, 6),
  gps_accuracy integer,
  vehicle_category text,
  vehicle_model text,
  vehicle_count text,
  connector_type text,
  battery_status text,
  current_battery_level text,
  charging_need text,
  charging_details text,
  preferred_window text,
  target_date date,
  preferred_time text,
  pilot_interest text,
  message text,
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'new',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint pvg_ev_request_form_type_check
    check (form_type in ('request', 'contact', 'fleet', 'pilot')),
  constraint pvg_ev_request_status_check
    check (status in ('new', 'reviewing', 'contacted', 'closed', 'spam')),
  constraint pvg_ev_request_source_check
    check (source = 'pvg_ev_website')
);

comment on table public.pvg_ev_charging_requests is
  'PVG-EV website charging and pilot enquiries. Isolated from ClickaCook application data.';
comment on column public.pvg_ev_charging_requests.payload is
  'Complete submitted form payload retained for operational review.';

create index if not exists pvg_ev_requests_created_at_idx
  on public.pvg_ev_charging_requests (created_at desc);
create index if not exists pvg_ev_requests_status_created_idx
  on public.pvg_ev_charging_requests (status, created_at desc);
create index if not exists pvg_ev_requests_phone_idx
  on public.pvg_ev_charging_requests (phone);
create index if not exists pvg_ev_requests_form_type_idx
  on public.pvg_ev_charging_requests (form_type);

create or replace function public.set_pvg_ev_charging_requests_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists set_pvg_ev_charging_requests_updated_at
  on public.pvg_ev_charging_requests;
create trigger set_pvg_ev_charging_requests_updated_at
before update on public.pvg_ev_charging_requests
for each row execute function public.set_pvg_ev_charging_requests_updated_at();

alter table public.pvg_ev_charging_requests enable row level security;

drop policy if exists "PVG-EV website can submit new requests"
  on public.pvg_ev_charging_requests;
create policy "PVG-EV website can submit new requests"
on public.pvg_ev_charging_requests
for insert
to anon
with check (
  source = 'pvg_ev_website'
  and status = 'new'
  and length(trim(phone)) between 10 and 16
  and length(trim(reference)) between 12 and 64
);

drop policy if exists "Authenticated users can review PVG-EV requests"
  on public.pvg_ev_charging_requests;
drop policy if exists "Authenticated users can update PVG-EV requests"
  on public.pvg_ev_charging_requests;

revoke all on table public.pvg_ev_charging_requests from public, anon, authenticated;
grant insert on public.pvg_ev_charging_requests to anon;
grant select, insert, update, delete on public.pvg_ev_charging_requests to service_role;
