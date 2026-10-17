begin;

-- One server-issued number for every enquiry type. Existing references stay valid.
create sequence if not exists public.pvg_ev_enquiry_reference_seq
  as bigint start with 1001;
revoke all on sequence public.pvg_ev_enquiry_reference_seq from public, anon, authenticated;

create or replace function public.submit_pvg_ev_enquiry(
  p_submission_id uuid,
  p_enquiry jsonb
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  candidate public.pvg_ev_charging_requests%rowtype;
  existing public.pvg_ev_charging_requests%rowtype;
  generated_reference text;
begin
  if p_submission_id is null or jsonb_typeof(p_enquiry) is distinct from 'object'
     or octet_length(p_enquiry::text) > 32000 then
    raise exception 'Invalid enquiry' using errcode = '22023';
  end if;
  candidate := jsonb_populate_record(null::public.pvg_ev_charging_requests, p_enquiry);
  -- Only website submissions are accepted; clients cannot set operational state.
  candidate.id := p_submission_id;
  candidate.source := 'pvg_ev_website';
  candidate.status := 'new';
  candidate.phone := btrim(candidate.phone);
  if candidate.form_type is null or candidate.form_type not in ('request','contact','fleet','pilot')
     or candidate.phone is null or candidate.phone !~ '^[6-9][0-9]{9}$'
     or nullif(btrim(candidate.name),'') is null
     or jsonb_typeof(candidate.payload) is distinct from 'object'
     or candidate.payload->'consent' is distinct from 'true'::jsonb
     or coalesce(candidate.payload->>'website','') <> '' then
    raise exception 'Invalid enquiry details or consent' using errcode = '22023';
  end if;

  -- Serialize only retries of the same private submission ID.
  perform pg_advisory_xact_lock(hashtextextended(p_submission_id::text, 0));
  select * into existing from public.pvg_ev_charging_requests where id = p_submission_id;
  if found then
    if (to_jsonb(existing) - array['id','reference','created_at','updated_at','status'])
       is distinct from
       (to_jsonb(candidate) - array['id','reference','created_at','updated_at','status']) then
      raise exception 'Submission ID already used for different details' using errcode = '22023';
    end if;
    return jsonb_build_object('reference', existing.reference);
  end if;

  generated_reference := 'PVG-' || nextval('public.pvg_ev_enquiry_reference_seq'::regclass)::text;
  insert into public.pvg_ev_charging_requests (
    id, reference, source, form_type, status, requirement_type, customer_type,
    requirement_scope, priority, use_case, phone, name, email, company, city,
    location_type, address, gps_location, latitude, longitude, gps_accuracy,
    vehicle_category, vehicle_model, vehicle_count, connector_type, battery_status,
    current_battery_level, charging_need, charging_details, preferred_window,
    target_date, preferred_time, pilot_interest, message, payload
  ) values (
    p_submission_id, generated_reference, 'pvg_ev_website', candidate.form_type, 'new',
    candidate.requirement_type, candidate.customer_type, candidate.requirement_scope,
    candidate.priority, candidate.use_case, candidate.phone, candidate.name,
    candidate.email, candidate.company, candidate.city, candidate.location_type,
    candidate.address, candidate.gps_location, candidate.latitude, candidate.longitude,
    candidate.gps_accuracy, candidate.vehicle_category, candidate.vehicle_model,
    candidate.vehicle_count, candidate.connector_type, candidate.battery_status,
    candidate.current_battery_level, candidate.charging_need, candidate.charging_details,
    candidate.preferred_window, candidate.target_date, candidate.preferred_time,
    candidate.pilot_interest, candidate.message, candidate.payload
  );
  return jsonb_build_object('reference', generated_reference);
end;
$$;

revoke all on function public.submit_pvg_ev_enquiry(uuid, jsonb) from public, authenticated;
grant execute on function public.submit_pvg_ev_enquiry(uuid, jsonb) to anon;
comment on function public.submit_pvg_ev_enquiry(uuid, jsonb) is
  'Saves a PVG website enquiry and returns only its short reference. A matching private submission ID and payload safely retry the same enquiry. Does not expose enquiry records or change table read permissions.';

notify pgrst, 'reload schema';
commit;
