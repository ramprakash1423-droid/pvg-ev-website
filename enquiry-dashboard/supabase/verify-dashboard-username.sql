-- All fixtures, credentials, sessions and status changes roll back.
begin;
insert into pvg_private.dashboard_credentials(username,password_hash)
values('admin',extensions.crypt('PVG-QA-only-password',extensions.gen_salt('bf',4)))
on conflict(username) do update set password_hash=excluded.password_hash,credential_version=gen_random_uuid(),failed_attempts=0,locked_until=null;
insert into public.pvg_ev_charging_requests(id,reference,form_type,phone,name,message,payload)
values('f52f5372-39c0-4f86-89cb-2f317fa34cd5','PVG-DASHBOARD-ACCESS-QA','contact','9000000099','PVG dashboard access QA','Do not contact. Transaction-only test.','{"consent":true,"qa_test":true}'::jsonb);
set local role anon;
do $$
declare result jsonb;
begin
  begin perform * from pvg_private.dashboard_credentials;raise exception 'FAIL: credentials are readable';exception when insufficient_privilege then null;end;
  begin perform * from pvg_private.dashboard_sessions;raise exception 'FAIL: sessions are readable';exception when insufficient_privilege then null;end;
  begin perform id from public.pvg_ev_charging_requests limit 1;raise exception 'FAIL: direct enquiry access';exception when insufficient_privilege then null;end;
  begin perform public.pvg_dashboard_session_list(null);raise exception 'FAIL: null session accepted';exception when sqlstate 'PT401' then null;end;
  begin perform public.pvg_dashboard_session_list(repeat('a',64));raise exception 'FAIL: invented session accepted';exception when sqlstate 'PT401' then null;end;
  begin perform public.pvg_dashboard_session_update_status(repeat('a',64),'f52f5372-39c0-4f86-89cb-2f317fa34cd5','closed',now());raise exception 'FAIL: update without session';exception when sqlstate 'PT401' then null;end;
  for i in 1..5 loop
    result:=public.pvg_dashboard_login('admin','wrong-password');
    if result->>'ok'<>'false' then raise exception 'FAIL: bad password accepted';end if;
  end loop;
  result:=public.pvg_dashboard_login('admin','PVG-QA-only-password');
  if result->>'error'<>'rate_limited' then raise exception 'FAIL: lockout not enforced';end if;
end $$;
reset role;
do $$ begin
 if not exists(select 1 from pvg_private.dashboard_credentials where username='admin' and failed_attempts=5 and locked_until>now())then raise exception 'FAIL: failed attempts did not persist';end if;
end $$;
update pvg_private.dashboard_credentials set locked_until=now()-interval '1 second' where username='admin';
set local role anon;
do $$
declare result jsonb; original jsonb; changed jsonb; token text;
begin
  result:=public.pvg_dashboard_login('admin','PVG-QA-only-password');token:=result->>'session_token';
  if result->>'ok'<>'true' or length(token)<>64 then raise exception 'FAIL: valid login failed';end if;
  result:=public.pvg_dashboard_session_list(token,p_search=>'PVG-DASHBOARD-ACCESS-QA');
  if (result->>'total')::int<>1 then raise exception 'FAIL: enquiry not readable';end if;
  original:=result->'records'->0;
  changed:=public.pvg_dashboard_session_update_status(token,(original->>'id')::uuid,'contacted',(original->>'updated_at')::timestamptz);
  if changed->>'status'<>'contacted' then raise exception 'FAIL: status not updated';end if;
  begin perform public.pvg_dashboard_session_update_status(token,(original->>'id')::uuid,'closed','2000-01-01');raise exception 'FAIL: stale write accepted';exception when sqlstate 'PT409' then null;end;
  begin perform public.pvg_dashboard_session_update_status(token,(original->>'id')::uuid,'deleted',(changed->>'updated_at')::timestamptz);raise exception 'FAIL: bad status accepted';exception when invalid_parameter_value then null;end;
  begin perform public.pvg_dashboard_session_list(token,p_limit=>100000);raise exception 'FAIL: unbounded data';exception when invalid_parameter_value then null;end;
  result:=public.pvg_dashboard_session_list(token,p_search=>'PVG-DASHBOARD-ACCESS-QA');
  if ((result->'records'->0)-array['status','updated_at']) is distinct from (original-array['status','updated_at']) then raise exception 'FAIL: customer fields changed';end if;
  perform public.pvg_dashboard_logout(token);
  begin perform public.pvg_dashboard_session_list(token);raise exception 'FAIL: logged-out session works';exception when sqlstate 'PT401' then null;end;
  token:=public.pvg_dashboard_login('admin','PVG-QA-only-password')->>'session_token';
  perform set_config('pvg.qa_token',token,true);
end $$;
reset role;
do $$ begin
 if not exists(select 1 from pvg_private.enquiry_status_history where enquiry_id='f52f5372-39c0-4f86-89cb-2f317fa34cd5' and changed_by is null and actor_label='PVG admin' and new_status='contacted')then raise exception 'FAIL: audit missing';end if;
 if not exists(select 1 from pvg_private.dashboard_sessions where token_hash=extensions.digest(current_setting('pvg.qa_token'),'sha256'))then raise exception 'FAIL: token not hashed';end if;
end $$;
update pvg_private.dashboard_sessions set expires_at=now()-interval '1 second' where token_hash=extensions.digest(current_setting('pvg.qa_token'),'sha256');
set local role anon;
do $$ begin
 begin perform public.pvg_dashboard_session_list(current_setting('pvg.qa_token'));raise exception 'FAIL: expired session works';exception when sqlstate 'PT401' then null;end;
end $$;
reset role;
set local role authenticated;
do $$ begin
 begin perform public.pvg_dashboard_list();raise exception 'FAIL: former Google endpoint still accessible';exception when insufficient_privilege then null;end;
 begin perform pvg_private.dashboard_list();raise exception 'FAIL: private core callable';exception when insufficient_privilege then null;end;
end $$;
reset role;
rollback;
select jsonb_build_object('password_login',true,'private_hashes_and_sessions',true,'missing_and_invalid_sessions_denied',true,'failed_attempts_persist',true,'lockout_enforced',true,'list_and_status_update',true,'customer_fields_preserved',true,'stale_and_invalid_updates_denied',true,'audit_correct',true,'logout_and_expiry',true,'old_google_endpoint_retired',true,'fixtures_rolled_back',true) as verification;
