/* Customer data, passwords and PVG session tokens are never stored in browser storage. */
(()=>{
  'use strict';
  const D=window.PVGDashboard,$=id=>document.getElementById(id);
  const local=['127.0.0.1','localhost'].includes(location.hostname);
  const preview=local&&new URLSearchParams(location.search).get('preview')==='1';
  // Activate only after applying and verifying the private dashboard migration.
  const liveEnabled=window.PVG_DASHBOARD_LIVE_ENABLED===true;
  const A=window.PVGDashboardAuth;
  // Remove stale return parameters from the retired Google flow without following them.
  if(['code','error','error_code','access_token'].some(key=>new URLSearchParams(location.search).has(key))||location.hash.includes('access_token='))history.replaceState(null,'',location.pathname);
  try{sessionStorage.removeItem('pvg-dashboard-google-pkce-v1');}catch{/* Storage may be disabled. */}
  const auth=A.create({url:window.PVG_CONFIG.url,key:window.PVG_CONFIG.key,fetch:window.fetch.bind(window)});
  let session=null,expiryTimer=null,refreshTimer=null,requestVersion=0,searchTimer=null,toastTimer=null;
  const state={type:'all',status:'all',date:'all',search:'',source:'sample',offset:0,records:[],selected:null,total:0,busy:false,saving:false};
  const node=(tag,className,text)=>{const e=document.createElement(tag);if(className)e.className=className;if(text!==undefined)e.textContent=text;return e;};
  const fmtDate=value=>value?new Intl.DateTimeFormat('en-IN',{timeZone:'Asia/Kolkata',day:'numeric',month:'short',hour:'numeric',minute:'2-digit'}).format(new Date(value)):'Not provided';
  const setMessage=(id,message)=>{$(id).textContent=message;$(id).hidden=!message;};
  const showToast=message=>{clearTimeout(toastTimer);setMessage('toast',message);toastTimer=setTimeout(()=>$('toast').hidden=true,4500);};
  const badge=status=>node('span',`status-badge status-${Object.hasOwn(D.statuses,status)?status:'new'}`,D.statuses[status]||status);
  function resetDetails(){const box=node('div','detail-empty');box.append(node('span','eyebrow','The full picture'),node('h2','','Get to know the request.'),node('p','','Select an enquiry to see the customer’s details, location and requirements.'));$('detail-panel').replaceChildren(box);}
  function clearSession(message='You have signed out.'){
    session=null;requestVersion++;clearTimeout(expiryTimer);clearInterval(refreshTimer);state.records=[];state.selected=null;state.total=0;
    $('enquiry-list').replaceChildren();resetDetails();for(const key of ['total','new','active','closed'])$(`stat-${key}`).textContent='—';$('nav-total').textContent='—';
    $('workspace').hidden=true;$('login-panel').hidden=false;$('sign-out').hidden=true;$('admin-password').value='';state.busy=false;setLoginBusy(false);setMessage('login-message',message);
  }
  function rememberSession(data){session=data;clearTimeout(expiryTimer);expiryTimer=setTimeout(()=>clearSession('Your session has expired. Please sign in again.'),Math.max(1,(data.expires_in||3600)-30)*1000);}
  async function request(path,body,method='POST'){
    let response;
    if(preview){response=await fetch(`/__preview/dashboard${path}`,{method,headers:{'Content-Type':'application/json','X-PVG-Preview':'dashboard'},cache:'no-store',body:method==='GET'?undefined:JSON.stringify(body),signal:AbortSignal.timeout(12000)});}
    else{
      if(!liveEnabled||!session)throw new Error('Live access is not activated.');
      response=await fetch(`${window.PVG_CONFIG.url}/rest/v1/rpc/${path}`,{method:'POST',headers:{apikey:window.PVG_CONFIG.key,'Content-Type':'application/json'},body:JSON.stringify({...body,p_session_token:session.session_token}),cache:'no-store',signal:AbortSignal.timeout(12000)});
    }
    if(!response.ok){
      if(response.status===401&&!preview){clearSession('Your session has expired. Please sign in again.');throw new Error('Please sign in again.');}
      if(response.status===403){if(!preview)clearSession('This account does not have access to the private PVG dashboard.');throw new Error('This account does not have access to the private PVG dashboard.');}
      if(response.status===409)throw new Error('This request changed elsewhere. Refresh before saving again.');
      if(response.status===404)throw new Error('The dashboard connection is not active yet.');
      throw new Error('We could not complete that action. Please try again.');
    }
    return response.json();
  }
  async function load({background=false}={}){
    if(state.saving)return;
    const version=++requestVersion;state.busy=true;$('refresh').disabled=true;
    if(!background){$('enquiry-list').setAttribute('aria-busy','true');setMessage('list-error','');}
    const params={search:state.search,type:state.type,status:state.status,since:D.dateStart(state.date),offset:state.offset,limit:D.pageSize};
    try{
      const result=preview?await request(`?${new URLSearchParams({...params,since:params.since||'',source:state.source})}`,null,'GET'):await request('pvg_dashboard_session_list',Object.fromEntries(Object.entries(params).map(([key,value])=>['p_'+key,value])));
      if(version!==requestVersion)return;
      state.records=result.records;state.total=result.total;
      if(state.offset>0&&state.offset>=state.total){state.offset=0;return load();}
      setMessage('list-error','');
      for(const key of ['total','new','active','closed'])$(`stat-${key}`).textContent=result.stats[key];
      $('nav-total').textContent=result.stats.total;
      $('welcome-note').textContent=result.stats.new?`${result.stats.new} new ${result.stats.new===1?'enquiry needs':'enquiries need'} a first response.`:'You’re all caught up with new enquiries.';
      $('results-label').textContent=state.total?`${state.offset+1}–${Math.min(state.offset+D.pageSize,state.total)} of ${state.total} ${state.total===1?'enquiry':'enquiries'}`:'No matching enquiries';
      $('page-label').textContent=`${Math.floor(state.offset/D.pageSize)+1} / ${Math.max(1,Math.ceil(state.total/D.pageSize))}`;
      $('previous-page').disabled=state.offset===0;$('next-page').disabled=state.offset+D.pageSize>=state.total;
      $('updated-label').textContent=`Updated ${new Intl.DateTimeFormat('en-IN',{hour:'numeric',minute:'2-digit'}).format(new Date())} · auto-refresh 60s`;
      const selected=state.records.find(r=>r.id===state.selected);
      if(!selected)state.selected=state.records[0]?.id||null;
      renderList();
      // Do not overwrite a status being chosen during an automatic refresh.
      if(!background||!$('detail-panel').contains(document.activeElement))renderDetail(state.records.find(r=>r.id===state.selected));
    }catch(error){if(version===requestVersion){setMessage('list-error',error.name==='TimeoutError'?'The connection timed out. Please refresh to try again.':error.message);$('updated-label').textContent='Refresh failed · previously loaded data may be out of date';}}
    finally{if(version===requestVersion){state.busy=false;$('refresh').disabled=false;$('enquiry-list').removeAttribute('aria-busy');}}
  }
  function renderList(){
    const rows=state.records.map(record=>{
      const button=node('button',`enquiry-row${record.id===state.selected?' selected':''}`);button.type='button';button.setAttribute('aria-pressed',String(record.id===state.selected));button.setAttribute('aria-label',`${record.reference}, ${record.name||'Unnamed enquiry'}, ${D.types[record.form_type]}, ${D.statuses[record.status]}`);
      const initials=(record.name||'PVG').trim().split(/\s+/).slice(0,2).map(v=>v[0]).join('').toUpperCase();
      const icon=node('span','row-avatar',initials);icon.setAttribute('aria-hidden','true');const main=node('div','row-main');
      main.append(node('strong','',record.name||'Unnamed enquiry'),node('p','',record.company||record.requirement_type||D.types[record.form_type]));
      const meta=node('div','row-meta');meta.append(node('span','',record.reference),node('span','','·'),node('span','',D.types[record.form_type]));main.append(meta);
      const end=node('div','row-end');const date=node('time','',new Intl.DateTimeFormat('en-IN',{timeZone:'Asia/Kolkata',day:'numeric',month:'short'}).format(new Date(record.created_at)));date.dateTime=record.created_at;end.append(badge(record.status),date);button.append(icon,main,end);
      button.addEventListener('click',()=>{state.selected=record.id;renderList();renderDetail(record);if(matchMedia('(max-width:960px)').matches){$('detail-panel').scrollIntoView({behavior:matchMedia('(prefers-reduced-motion:reduce)').matches?'auto':'smooth'});$('detail-name').focus({preventScroll:true});}});return button;
    });
    $('enquiry-list').replaceChildren(...rows);$('empty-state').hidden=!!rows.length;
  }
  function detailSection(title){const section=node('section','detail-section');section.append(node('h3','',title));return section;}
  function facts(section,values){const list=node('dl');values.forEach(([label,value])=>{if(value===null||value===undefined||value==='')return;const row=node('div','detail-line');row.append(node('dt','',label),node('dd','',D.displayValue(value)));list.append(row);});section.append(list);}
  function renderDetail(record){
    if(!record){resetDetails();return;}
    const head=node('div','detail-head');const top=node('div','detail-topline');top.append(node('span','',record.reference),badge(record.status));
    const back=node('button','quiet-button mobile-back','Back to enquiries');back.type='button';back.addEventListener('click',()=>{$('inbox-heading').scrollIntoView({behavior:'smooth'});$('search').focus({preventScroll:true});});
    const name=node('h2','',record.name||'Unnamed enquiry');name.id='detail-name';name.tabIndex=-1;head.append(back,top,name,node('p','',`${D.types[record.form_type]} · ${fmtDate(record.created_at)} IST`));
    const body=node('div','detail-body'),contact=detailSection('Customer details');
    facts(contact,[['Phone',record.phone],['Email',record.email],['Organisation',record.company]]);
    const digits=D.phoneDigits(record.phone),actions=node('div','contact-actions');
    if(preview){actions.append(node('span','disabled-link','Call (preview)'),node('span','disabled-link','WhatsApp (preview)'));}
    else if(digits){const call=node('a','','Call customer');call.href=`tel:+${digits}`;const wa=node('a','','WhatsApp');wa.href=`https://wa.me/${digits}`;wa.target='_blank';wa.rel='noopener noreferrer';actions.append(call,wa);}
    contact.append(actions);body.append(contact);
    const requirement=detailSection('What they need');facts(requirement,[['Requirement',record.requirement_type],['Vehicle',record.vehicle_model||record.vehicle_category],['Vehicles',record.vehicle_count],['Battery level',record.current_battery_level!==null&&record.current_battery_level!==undefined&&record.current_battery_level!==''?`${record.current_battery_level}%`:null],['Preferred date',record.target_date],['Preferred time',record.preferred_time||record.preferred_window],['Priority',record.priority]]);
    const message=record.message||record.charging_details||record.payload?.message||record.payload?.charging_details;if(message)requirement.append(node('p','detail-message',D.displayValue(message)));body.append(requirement);
    const location=detailSection('Location');facts(location,[['Area',record.city],['Address',record.address],['GPS accuracy',record.gps_accuracy?`Within ${record.gps_accuracy} m`:null]]);const map=D.mapUrl(record);if(map){const link=node('a','map-link',preview?'View sample location on map':'Open GPS location in Maps');link.href=map;link.target='_blank';link.rel='noopener noreferrer';location.append(link);}else location.append(node('p','help-text','GPS coordinates were not provided for this enquiry.'));body.append(location);
    const followUp=detailSection('Follow-up status'),control=node('form','status-control'),select=node('select');select.setAttribute('aria-label','Enquiry status');for(const [value,label] of Object.entries(D.statuses)){const option=node('option','',label);option.value=value;select.append(option);}select.value=record.status;
    const save=node('button','primary-button','Save status');save.type='submit';save.disabled=true;select.addEventListener('change',()=>save.disabled=select.value===record.status);control.append(select,save);
    const statusMessage=node('p','help-text',preview?'Changes are saved on this computer only.':'Changing a status does not send a message to the customer.');statusMessage.setAttribute('role','status');
    control.addEventListener('submit',async event=>{
      event.preventDefault();if(state.saving||select.value===record.status)return;state.saving=true;save.disabled=true;select.disabled=true;save.textContent='Saving…';const viewVersion=requestVersion;const targetStatus=select.value;
      try{
        await request(preview?'':'pvg_dashboard_session_update_status',preview?{source:state.source,id:record.id,status:targetStatus,expected_updated_at:record.updated_at}:{p_id:record.id,p_status:targetStatus,p_expected_updated_at:record.updated_at},preview?'PATCH':'POST');
        showToast(preview?'Status saved in this local preview.':'Enquiry status saved.');state.saving=false;if(viewVersion===requestVersion)await load();
      }catch(error){statusMessage.textContent=error.message;statusMessage.classList.add('error');}
      finally{state.saving=false;save.disabled=select.value===record.status;select.disabled=false;save.textContent='Save status';}
    });followUp.append(control,statusMessage);body.append(followUp);
    const full=node('details','full-fields');full.append(node('summary','','All submitted details'));const all=node('dl');for(const field of D.fields(record,window.PVGFormSchema||{})){const entry=node('div','field-entry');entry.append(node('dt','',field.label),node('dd','',field.value));all.append(entry);}full.append(all);body.append(full);
    $('detail-panel').replaceChildren(head,body);
  }
  function setStatus(status){state.status=status;state.offset=0;$('status-filter').value=status;load();}
  function clearFilters(){state.search='';state.date='all';state.status='all';state.type='all';state.offset=0;$('search').value='';$('date-filter').value='all';$('status-filter').value='all';$('inbox-heading').textContent='All enquiries';document.querySelectorAll('[data-type]').forEach(el=>{const active=el.dataset.type==='all';el.classList.toggle('active',active);el.setAttribute('aria-pressed',String(active));});}
  $('category-nav').addEventListener('click',event=>{const button=event.target.closest('[data-type]');if(!button||$('workspace').hidden)return;state.type=button.dataset.type;state.offset=0;document.querySelectorAll('[data-type]').forEach(el=>{el.classList.toggle('active',el===button);el.setAttribute('aria-pressed',String(el===button));});$('inbox-heading').textContent=state.type==='all'?'All enquiries':D.types[state.type];load();});
  document.querySelectorAll('[data-status]').forEach(button=>button.addEventListener('click',()=>{clearFilters();setStatus(button.dataset.status);}));
  $('review-new').addEventListener('click',()=>{clearFilters();setStatus('new');$('inbox-heading').scrollIntoView({behavior:'smooth',block:'start'});});
  $('status-filter').addEventListener('change',e=>setStatus(e.target.value));
  $('date-filter').addEventListener('change',e=>{state.date=e.target.value;state.offset=0;load();});
  $('source-filter').addEventListener('change',e=>{state.source=e.target.value;state.offset=0;state.selected=null;$('preview-description').textContent=state.source==='sample'?'Sample enquiries only. No live customer data.':'Local form tests only. These requests stay on this computer.';load();});
  $('search').addEventListener('input',e=>{state.search=e.target.value;state.offset=0;clearTimeout(searchTimer);searchTimer=setTimeout(()=>load(),250);});
  $('refresh').addEventListener('click',()=>load());
  $('clear-filters').addEventListener('click',()=>{clearFilters();load();});
  $('previous-page').addEventListener('click',()=>{state.offset=Math.max(0,state.offset-D.pageSize);load();});$('next-page').addEventListener('click',()=>{state.offset+=D.pageSize;load();});
  function setLoginBusy(busy){$('login-submit').disabled=busy||!liveEnabled;$('login-submit').textContent=busy?'Signing in…':'Sign in';}
  const loginError=error=>error.name==='TimeoutError'?'Sign-in timed out. Please try again.':error.message==='Failed to fetch'?'Unable to connect. Check your internet connection and try again.':error.message;
  $('sign-out').addEventListener('click',async()=>{const token=session?.session_token;clearSession();try{await auth.revoke(token);}catch{setMessage('login-message','Signed out on this device. The server session will expire automatically.');}});
  $('login-form').addEventListener('submit',async event=>{
    event.preventDefault();if(!liveEnabled||preview||$('login-submit').disabled)return;
    // Local design previews do not receive the live dashboard password.
    if(local){location.assign(A.dashboardUrl);return;}
    setLoginBusy(true);setMessage('login-message','Checking your PVG dashboard account…');let authenticated;
    try{
      const pending=auth.login($('admin-username').value.trim(),$('admin-password').value);$('admin-password').value='';
      authenticated=await pending;rememberSession(authenticated);
      await request('pvg_dashboard_session_list',{p_limit:1});
      $('login-panel').hidden=true;$('workspace').hidden=false;$('sign-out').hidden=false;await load();startRefresh();
    }catch(error){try{await auth.revoke(authenticated?.session_token);}catch{}clearSession(loginError(error));}
    finally{setLoginBusy(false);}
  });
  function startRefresh(){clearInterval(refreshTimer);refreshTimer=setInterval(()=>{if(!document.hidden&&!state.saving&&!state.busy)load({background:true});},60000);}
  $('today-label').textContent=new Intl.DateTimeFormat('en-IN',{weekday:'long',day:'numeric',month:'long',timeZone:'Asia/Kolkata'}).format(new Date());
  if(local)$('preview-link').hidden=false;
  if(liveEnabled)setLoginBusy(false);
  else setMessage('login-message','Live sign-in is not activated yet.');
  if(preview){$('login-panel').hidden=true;$('workspace').hidden=false;$('preview-banner').hidden=false;$('source-filter-wrap').hidden=false;load();startRefresh();}
  window.addEventListener('pageshow',event=>{if(event.persisted&&!preview)clearSession('Please sign in again to view private enquiries.');});
})();
