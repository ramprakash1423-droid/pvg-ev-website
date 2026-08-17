begin;

alter table public.pvg_ev_charging_requests enable row level security;

drop policy if exists "Authenticated users can review PVG-EV requests"
  on public.pvg_ev_charging_requests;
drop policy if exists "Authenticated users can update PVG-EV requests"
  on public.pvg_ev_charging_requests;

revoke all on table public.pvg_ev_charging_requests from public, anon, authenticated;
grant insert on public.pvg_ev_charging_requests to anon;
grant select, insert, update, delete on public.pvg_ev_charging_requests to service_role;

commit;
