begin;

alter table public.pvg_ev_charging_requests
  drop constraint if exists pvg_ev_fast_request_contact_location_required;

alter table public.pvg_ev_charging_requests
  add constraint pvg_ev_fast_request_contact_location_required
  check (
    form_type <> 'request'
    or (
      nullif(btrim(phone), '') is not null
      and nullif(btrim(name), '') is not null
      and nullif(btrim(city), '') is not null
      and nullif(btrim(location_type), '') is not null
      and nullif(btrim(address), '') is not null
      and latitude is not null
      and latitude between -90 and 90
      and longitude is not null
      and longitude between -180 and 180
    )
  ) not valid;

comment on constraint pvg_ev_fast_request_contact_location_required
  on public.pvg_ev_charging_requests is
  'Requires complete contact details and captured coordinates for Fast Requests only.';

commit;
