import {GpsSharing,gpsPanelState} from './tracking-client.js';
import {LiveUpdates} from './live-updates.js';
/* Staff operations. Sessions stay in memory; every permission is enforced by the service. */
(() => {
  'use strict';
  const $=id=>document.getElementById(id);
  const state={currentBooking:null,token:null,user:null,bookings:[],selected:null,fleet:{vehicles:[],technicians:[]},view:'bookings',config:null,expiry:null};
  const labels={requested:'New request',assigned:'Assigned',on_the_way:'On the way',arrived:'Arrived',charging:'Charging',awaiting_acceptance:'Customer review',awaiting_payment:'Awaiting payment',paid:'Paid · test',disputed:'Needs attention',cancelled:'Cancelled'};
  const eventLabels={gps_started:'Technician enabled location sharing',gps_stopped:'Technician stopped location sharing',requested:'Customer requested a visit',assigned:'Vehicle & technician assigned',on_the_way:'Technician on the way',arrived:'Technician arrived',charging:'Charging marked as started',reading_submitted:'Reading sent to customer',customer_accepted:'Customer accepted units & bill',customer_reported_issue:'Customer reported an issue',payment_verified:'Test payment verified',cancelled:'Booking cancelled'};
  const esc=value=>String(value??'').replace(/[&<>"']/g,char=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
  const money=value=>new Intl.NumberFormat('en-IN',{style:'currency',currency:'INR',maximumFractionDigits:2}).format((value||0)/100);
  const when=value=>new Intl.DateTimeFormat('en-IN',{day:'numeric',month:'short',hour:'numeric',minute:'2-digit',timeZone:'Asia/Kolkata'}).format(new Date(value));
  const badge=status=>`<span class="badge ${esc(status)}">${esc(labels[status]||status)}</span>`;
  function notify(message){$('toast').textContent=message;$('toast').hidden=false;clearTimeout(notify.timer);notify.timer=setTimeout(()=>$('toast').hidden=true,4500);}
  async function api(path,data,{keepalive=false}={}){
    const response=await fetch(`/api${path}`,{method:data===undefined?'GET':'POST',headers:{...(state.token?{Authorization:`Bearer ${state.token}`} : {}),...(data!==undefined?{'Content-Type':'application/json'}:{})},body:data===undefined?undefined:JSON.stringify(data),cache:'no-store',keepalive,signal:AbortSignal.timeout(25000)});
    let result;try{result=await response.json();}catch{throw new Error('The operations server is not connected. Start the local PVG service to use this pilot.');}
    if(response.status===401&&state.token){signedOut();throw new Error('Your session expired. Please sign in again.');}
    if(!response.ok){const error=new Error(result.error||'Unable to complete the request.');error.status=response.status;throw error;}return result;
  }
  function signedOut(){live.stop();void gps.stop();state.currentBooking=null;clearTimeout(state.expiry);state.token=null;state.user=null;state.bookings=[];state.selected=null;$('bookings-list').replaceChildren();$('job-detail').replaceChildren();$('workspace').hidden=true;$('sign-in').hidden=false;$('staff-login').reset();}
  async function login(username,password){
    $('login-error').hidden=true;
    const auth=await api('/auth/login',{username,password});
    state.token=auth.token;state.user=auth.user;
    $('staff-login').reset();$('sign-in').hidden=true;$('workspace').hidden=false;
    $('user-name').textContent=auth.user.name;$('user-role').textContent=auth.user.role==='admin'?'Administrator':'Technician';$('user-initials').textContent=auth.user.name.slice(0,2).toUpperCase();
    document.querySelectorAll('.admin-only').forEach(el=>el.hidden=auth.user.role!=='admin');
    const isTech=auth.user.role==='technician';$('jobs-label').textContent=isTech?'My jobs':'Bookings';$('page-heading').textContent=isTech?'Your assigned jobs':'Charging operations';$('welcome-title').textContent=isTech?'A great visit starts with you.':'Every visit, well coordinated.';$('welcome-copy').textContent=isTech?'Keep the customer updated. Submit the reading. They accept and pay.':'Plan the next job. Keep customers informed. Let them accept and pay.';
    if(auth.user.role==='admin')state.fleet=await api('/fleet');
    if(state.config?.realtime)live.start(state.token);
    state.view='bookings';await refresh();clearTimeout(state.expiry);state.expiry=setTimeout(()=>{if(state.token){api('/auth/logout',{}).catch(()=>{});signedOut();notify('Session expired. Please sign in again.');}},auth.expires_in*1000);
  }
  async function refresh(){
    $('page-error').hidden=true;
    try{state.bookings=(await api('/bookings')).bookings;render();if(state.selected)await select(state.selected,false);}
    catch(error){$('page-error').textContent=error.message;$('page-error').hidden=false;}
  }
  function render(){
    const all=state.bookings;
    $('open-count').textContent=all.filter(b=>!['paid','cancelled'].includes(b.status)).length;
    $('accept-count').textContent=all.filter(b=>b.status==='awaiting_acceptance').length;
    $('payment-count').textContent=all.filter(b=>b.status==='awaiting_payment').length;
    $('paid-count').textContent=all.filter(b=>b.status==='paid').length;
    $('issue-count').textContent=all.filter(b=>b.status==='disputed').length;
    const fleet=state.view==='fleet';$('fleet-view').hidden=!fleet;$('bookings-view').hidden=fleet;
    document.querySelectorAll('[data-view]').forEach(button=>{button.classList.toggle('active',button.dataset.view===state.view);button.setAttribute('aria-current',button.dataset.view===state.view?'page':'false');});
    if(fleet){renderFleet();return;}
    $('list-heading').textContent=state.view==='issues'?'Needs attention':state.user.role==='technician'?'My assigned jobs':'All bookings';
    $('list-caption').textContent=state.view==='issues'?'Resolve the issue; the customer accepts the corrected reading.':'Requested times are confirmed when a vehicle is assigned.';
    const search=$('search').value.toLowerCase().trim(),status=$('status').value;
    const rows=all.filter(b=>(state.view!=='issues'||b.status==='disputed')&&(status==='all'||b.status===status)&&`${b.reference} ${b.customer.name} ${b.address} ${b.ev.model}`.toLowerCase().includes(search));
    $('result-count').textContent=`${rows.length} ${rows.length===1?'job':'jobs'}`;
    $('bookings-list').innerHTML=rows.length?rows.map(b=>`<button class="booking-row ${state.selected===b.id?'selected':''}" data-booking="${esc(b.id)}" aria-label="Open ${esc(b.reference)}"><div><div class="row-overline">${esc(b.reference)} · ${esc(when(b.slot))}</div><div class="row-name">${esc(b.customer.name)}</div><p class="row-location">${esc(b.ev.model)} · ${esc(b.address)}</p></div><div class="row-end">${badge(b.status)}<small>${money(b.reading?.bill.total_paise||b.estimate.total_paise)}${b.reading?'':' estimated'}</small></div></button>`).join(''):'<div class="empty"><h2>No jobs here.</h2><p>Try another filter or refresh after a new booking is made.</p></div>';
    $('bookings-list').querySelectorAll('[data-booking]').forEach(button=>button.addEventListener('click',()=>select(button.dataset.booking,true)));
  }
  function line(label,value){return `<div class="detail-line"><span>${esc(label)}</span><strong>${esc(value)}</strong></div>`;}
  function billMarkup(bill,estimated=false){return `${line(estimated?'Estimated energy':'Energy delivered',`${bill.energy_milli/1000} kWh`)}${line('Agreed unit rate',`${money(bill.unit_rate_paise)} / kWh`)}${line('Energy charge',money(bill.energy_paise))}${line('Visit fee',money(bill.visit_fee_paise))}${line(`Tax (${bill.tax_basis_points/100}%)`,money(bill.tax_paise))}<div class="detail-line total"><span>Total</span><strong>${money(bill.total_paise)}</strong></div>`;}
  async function select(bookingId,scroll){
    try{
      const b=await api(`/bookings/${bookingId}`);state.currentBooking=b;state.selected=bookingId;render();if(gps.bookingId===b.id&&!b.tracking?.eligible)await gps.stop();
      const admin=state.user.role==='admin',tech=state.user.role==='technician';
      let action='';
      if(admin&&['requested','assigned'].includes(b.status)){
        const date=new Date(new Date(b.slot).getTime()-new Date().getTimezoneOffset()*60000).toISOString().slice(0,16);
        action=`<section class="detail-section"><h3>Plan this visit</h3><form id="assign-form"><label>Charging vehicle<select name="fleet_id" required>${state.fleet.vehicles.map(v=>`<option value="${esc(v.id)}" ${v.id===b.fleet_id?'selected':''}>${esc(v.name)}</option>`).join('')}</select></label><label>Technician<select name="technician_id" required>${state.fleet.technicians.map(t=>`<option value="${esc(t.id)}" ${t.id===b.technician?.id?'selected':''}>${esc(t.name)}</option>`).join('')}</select></label><label>Arrival time (this device’s local time)<input name="slot" type="datetime-local" value="${date}" required></label><label class="check-label"><input type="checkbox" name="compatibility_confirmed" required> I have checked EV/connector compatibility with this charging vehicle.</label><p class="small muted">A two-hour window includes travel and service. Overlapping assignments are blocked.</p><button class="primary step-action" type="submit">${b.status==='assigned'?'Update assignment':'Confirm & assign visit'}</button></form></section>`;
      }
      const next={assigned:['on_the_way','Mark on the way'],on_the_way:['arrived','Mark arrived'],arrived:['charging','Mark charging started']}[b.status];
      if(tech&&next)action=`<section class="detail-section"><h3>Your next step</h3><button class="primary step-action" id="next-stage" data-next="${next[0]}">${next[1]}</button><p class="small muted">This updates the customer. Operate the charger using Setrans.</p></section>`;
      if(tech&&['charging','awaiting_acceptance','disputed'].includes(b.status))action=`<section class="detail-section"><h3>${b.reading?'Submit a corrected reading':'Complete the charging record'}</h3>${b.dispute?`<p class="note attention">${esc(b.dispute)}</p>`:''}<form id="reading-form"><label>Reading type<select name="kind" id="reading-kind"><option value="session">Session energy (kWh delivered)</option><option value="cumulative">Cumulative meter (end minus start)</option></select></label><label id="session-units">Energy delivered (kWh)<input name="units" type="number" min="0.001" max="200" step="0.001" placeholder="e.g. 12.500" required></label><div id="cumulative-fields" hidden><div class="form-pair"><label>Starting meter (kWh)<input name="start" type="number" min="0" step="0.001"></label><label>Ending meter (kWh)<input name="end" type="number" min="0" step="0.001"></label></div><label>Starting meter photo<input name="start_photo" type="file" accept="image/jpeg,image/png,image/webp" capture="environment"></label></div><label>Session / ending meter photo<input name="photo" type="file" accept="image/jpeg,image/png,image/webp" capture="environment" required></label><label>Service notes (optional)<textarea name="notes" maxlength="1000" placeholder="Anything the customer should know"></textarea></label><p class="small muted">JPEG, PNG or WebP, up to 6 MB per photo. Rates are fixed by the booking. The customer must accept the latest reading.</p><button class="primary step-action" type="submit">Send units & bill to customer</button></form></section>`;
      const statusNote={awaiting_acceptance:'The customer can now review the photo and accept the units and total. No admin approval is needed.',awaiting_payment:'The customer has accepted this reading. It is locked and ready for payment.',paid:'The test payment has been verified. No actual money was collected.',disputed:admin?'The customer reported an issue. Coordinate with the assigned technician to submit corrected evidence; the customer must accept it.':null}[b.status];
      $('job-detail').innerHTML=`<div class="detail-head"><div class="detail-meta"><span class="eyebrow">${esc(b.reference)}</span>${badge(b.status)}</div><h2>${esc(b.customer.name)}</h2><p>${esc(b.ev.model)} · ${esc(b.ev.registration)}</p></div><div class="detail-body"><section class="detail-section"><h3>The visit</h3>${line('Requested / assigned time',when(b.slot))}${line('Location',b.address)}${line('Connector',b.ev.connector)}${line('Charging vehicle',b.fleet_name||'Not assigned')}${line('Technician',b.technician?.name||'Not assigned')}${b.access_notes?`<p class="note">${esc(b.access_notes)}</p>`:''}<div class="button-row">${b.latitude!=null?`<a class="secondary" href="https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(b.latitude+','+b.longitude)}" target="_blank" rel="noopener">Open navigation ↗</a>`:`<a class="secondary" href="https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(b.address)}" target="_blank" rel="noopener">Open address ↗</a>`}</div></section><div id="gps-panel">${trackingMarkup(b)}</div>${action}${statusNote?`<section class="detail-section"><h3>${b.status==='disputed'?'Customer issue':'Customer acceptance & payment'}</h3><p class="note ${b.status==='disputed'?'attention':''}">${esc(statusNote)}</p>${b.dispute&&admin?`<p class="small">${esc(b.dispute)}</p>`:''}</section>`:''}<section class="detail-section"><h3>${b.reading?'Submitted reading':'Booking estimate'}${b.reading?' · revision '+b.reading.revision:''}</h3>${b.reading?`<img class="evidence" src="${b.reading.photo}" alt="Charger reading submitted by technician">${b.reading.start_photo?`<img class="evidence" src="${b.reading.start_photo}" alt="Starting meter reading">`:''}${b.reading.kind==='cumulative'?line('Meter calculation',`${b.reading.end_milli/1000} − ${b.reading.start_milli/1000} kWh`):''}`:''}${billMarkup(b.reading?.bill||b.estimate,!b.reading)}<p class="small muted">${esc(b.tariff.tax_note)}</p>${b.invoice?line('Zoho Books','Account setup pending'):''}${b.invoice?.accepted_at?line('Accepted by customer',when(b.invoice.accepted_at)):''}${b.status==='paid'?'<button class="link-button" id="download-receipt">Download test receipt (PDF)</button>':''}</section><section class="detail-section"><h3>Job timeline</h3><div class="timeline">${b.events.slice().reverse().map(e=>`<div class="timeline-item"><span class="timeline-dot"></span><div><strong>${esc(eventLabels[e.action]||e.action)}</strong><small>${esc(when(e.created_at))}${e.revision?' · reading '+e.revision:''}</small></div></div>`).join('')}</div></section>${admin&&['requested','assigned'].includes(b.status)?'<button class="link-button" id="cancel-job">Cancel booking</button>':''}</div>`;
      bindGps(b);
      const act=async(task,message)=>{try{await task();notify(message);await refresh();}catch(error){notify(error.message);}};
      $('assign-form')?.addEventListener('submit',async event=>{event.preventDefault();const form=event.currentTarget,data=new FormData(form),button=form.querySelector('button');button.disabled=true;await act(()=>api(`/bookings/${b.id}/assign`,{version:b.version,fleet_id:data.get('fleet_id'),technician_id:data.get('technician_id'),slot:new Date(data.get('slot')).toISOString(),compatibility_confirmed:data.get('compatibility_confirmed')==='on'}),'Visit assigned.');button.disabled=false;});
      $('next-stage')?.addEventListener('click',event=>{event.currentTarget.disabled=true;act(()=>api(`/bookings/${b.id}/status`,{version:b.version,status:next[0]}),'Customer status updated.').finally(()=>{if($('next-stage'))$('next-stage').disabled=false;});});
      $('reading-kind')?.addEventListener('change',event=>{const cumulative=event.target.value==='cumulative';$('cumulative-fields').hidden=!cumulative;$('session-units').hidden=cumulative;$('session-units').querySelector('input').required=!cumulative;$('cumulative-fields').querySelectorAll('input').forEach(input=>input.required=cumulative);});
      $('reading-form')?.addEventListener('submit',async event=>{event.preventDefault();const form=event.currentTarget,data=new FormData(form),button=form.querySelector('button');button.disabled=true;try{const payload={version:b.version,kind:data.get('kind'),units:data.get('units'),start:data.get('start'),end:data.get('end'),notes:data.get('notes'),photo:await readPhoto(data.get('photo'))};if(payload.kind==='cumulative')payload.start_photo=await readPhoto(data.get('start_photo'));await api(`/bookings/${b.id}/reading`,payload);notify('Reading sent directly to the customer.');await refresh();}catch(error){notify(error.message);}finally{button.disabled=false;}});
      $('download-receipt')?.addEventListener('click',()=>downloadReceipt(b.id));
      $('cancel-job')?.addEventListener('click',()=>{if(confirm(`Cancel ${b.reference}?`))act(()=>api(`/bookings/${b.id}/cancel`,{version:b.version}),'Booking cancelled.');});
      if(scroll&&matchMedia('(max-width:1150px)').matches)$('job-detail').scrollIntoView({behavior:'smooth',block:'start'});
    }catch(error){if([403,404].includes(error.status)){if(gps.bookingId===bookingId)await gps.stop();state.currentBooking=null;state.selected=null;$('job-detail').innerHTML='<div class="empty"><h2>Visit unavailable</h2><p>This visit may have been reassigned. Refresh your jobs.</p></div>'; }notify(error.message);}
  }
  function readPhoto(file){return new Promise((resolve,reject)=>{if(!file?.size||file.size>6*1024*1024){reject(new Error('Choose a photo up to 6 MB.'));return;}const reader=new FileReader();reader.onload=()=>resolve(reader.result);reader.onerror=()=>reject(new Error('Unable to read the photo.'));reader.readAsDataURL(file);});}
  async function downloadReceipt(bookingId){try{const response=await fetch(`/api/bookings/${bookingId}/receipt`,{headers:{Authorization:`Bearer ${state.token}`},cache:'no-store'});if(!response.ok)throw new Error('Receipt unavailable.');const blob=await response.blob(),url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download='pvg-test-receipt.pdf';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);}catch(error){notify(error.message);}}
  function renderFleet(){
    if(state.user.role!=='admin')return;
    $('fleet-view').innerHTML=`<div class="fleet-grid">${state.fleet.vehicles.map((v,i)=>{const jobs=state.bookings.filter(b=>b.fleet_id===v.id&&!['cancelled','paid'].includes(b.status));return `<article class="fleet-card"><span class="fleet-number">0${i+1}</span><h2>${esc(v.name)}</h2><p>${esc(v.registration)} · Setrans mobile charger</p><div class="fleet-job"><strong>${jobs.length} open ${jobs.length===1?'visit':'visits'}</strong>${jobs.map(b=>`<span>${esc(b.reference)} · ${esc(when(b.slot))}</span>`).join('')||'<span>No visits assigned</span>'}</div><p class="small">${esc(v.compatibility)}</p></article>`;}).join('')}</div><section class="team-list"><h2>Your technicians</h2>${state.fleet.technicians.map(t=>`<div class="team-member"><strong>${esc(t.name)}</strong><span>${state.bookings.filter(b=>b.technician?.id===t.id&&!['paid','cancelled'].includes(b.status)).length} open jobs · individual staff login</span></div>`).join('')}</section>`;
    addSetupForms();
  }

  function addSetupForms(){
    if(state.config?.mode!=='supabase')return;
    $('fleet-view').insertAdjacentHTML('beforeend',`<section class="setup-grid"><form id="add-vehicle" class="team-list"><span class="eyebrow">SERVICE VEHICLE</span><h2>Add a charging vehicle</h2><p class="small muted">Use the actual registration and connector specification.</p><label>Vehicle name<input name="name" required maxlength="80" placeholder="Name shown to customers"></label><label>Registration number<input name="registration" required maxlength="20" placeholder="Actual vehicle registration"></label><label>Connectors and charging specification<input name="compatibility" required maxlength="300" placeholder="e.g. CCS2, rated output"></label><button class="primary" type="submit">Add vehicle</button><p class="setup-error error" role="alert" hidden></p></form><form id="add-technician" class="team-list"><span class="eyebrow">YOUR TEAM</span><h2>Add a technician</h2><p class="small muted">Technicians see only their assigned visits. Share their login privately.</p><label>Full name<input name="name" required maxlength="80" autocomplete="off"></label><label>Mobile number<input name="phone" required pattern="[6-9][0-9]{9}" inputmode="tel" maxlength="10" autocomplete="off"></label><label>User ID<input name="username" required pattern="[a-z][a-z0-9._-]{2,39}" autocomplete="off"></label><label>Password<input name="password" type="password" required minlength="12" maxlength="128" autocomplete="new-password"></label><button class="primary" type="submit">Create technician account</button><p class="setup-error error" role="alert" hidden></p></form></section>`);
    for(const [formId,path]of [['add-vehicle','/fleet'],['add-technician','/technicians']])$(formId).addEventListener('submit',async event=>{
      event.preventDefault();const form=event.currentTarget,button=form.querySelector('button'),errorBox=form.querySelector('.setup-error'),data=Object.fromEntries(new FormData(form));button.disabled=true;errorBox.hidden=true;if(form.elements.password)form.elements.password.value='';
      try{await api(path,data);form.reset();state.fleet=await api('/fleet');renderFleet();notify(path==='/fleet'?'Vehicle added.':'Technician account created.');}catch(error){errorBox.textContent=error.message;errorBox.hidden=false;}finally{button.disabled=false;}
    });
  }

  const gps=new GpsSharing({api,geo:navigator.geolocation,onChange:updateGpsUi});
  const live=new LiveUpdates({onExpired:signedOut,onEvent:event=>{
    if(!state.token)return;
    if(event.kind==='connection_lost'){if($('gps-status'))$('gps-status').textContent='Reconnecting live updates. The last position may be outdated.';return;}
    if(event.kind==='booking_tracking'){if(event.booking_id===state.selected)void refreshGps();return;}
    if(event.kind==='fleet'||event.kind==='users'){if(state.user?.role==='admin')void api('/fleet').then(fleet=>{state.fleet=fleet;if(state.view==='fleet'&&!document.activeElement?.closest('form'))renderFleet();});return;}
    clearTimeout(live.refreshTimer);live.refreshTimer=setTimeout(async()=>{if(!state.token||document.hidden)return;try{state.bookings=(await api('/bookings')).bookings;render();if(state.selected&&!state.bookings.some(b=>b.id===state.selected)){await select(state.selected,false);return;}if(state.selected&&(event.booking_id===state.selected||['connected','reconnected'].includes(event.kind))){if($('job-detail').querySelector('form'))notify('Live update received. Refresh the booking before submitting changes.');else await select(state.selected,false);}}catch(error){notify(error.message);}},250);
  }});
  function updateGpsUi(){
    const banner=$('gps-sharing-banner');
    banner.hidden=!gps.bookingId;
    $('gps-sharing-message').textContent=gps.phase==='starting'?'Starting GPS…':gps.sample?'Sample GPS active':'GPS sharing active';
    if(gps.messageBookingId===state.selected&&$('gps-status'))$('gps-status').textContent=gps.message;
    if(state.currentBooking?.id===gps.messageBookingId&&$('gps-panel')&&gps.phase!==updateGpsUi.lastPhase){paintGps(state.currentBooking);}
    updateGpsUi.lastPhase=gps.phase;
  }
  function trackingMarkup(b){
    const t=b.tracking;if(!t)return '';
    const tech=state.user.role==='technician',p=t.position;
    const view=gpsPanelState(b,tech?gps:{}),current=view.active;
    return `<section class="detail-section gps-section"><h3>Visit GPS tracking</h3><p id="gps-status" class="${view.recoverableError?'error':''}" role="status">${esc(view.message)}</p>${t.source==='sample'?'<p class="note attention">Sample GPS location · no vehicle is being tracked.</p>':''}${p?`<p class="small muted">Last captured ${esc(when(p.captured_at))} · accuracy ±${Math.round(p.accuracy)} m</p><a class="secondary" href="https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(p.latitude+','+p.longitude)}" target="_blank" rel="noopener">Open ${t.state==='live'?'latest':'last known'} location ↗</a>`:''}${tech&&t.eligible?`<p class="small muted">Shares this phone’s GPS with this booking’s customer and PVG admin. Keep the dashboard visible and the phone unlocked. Sharing stops when the visit completes, you sign out, or you leave this page.</p>${current?'<button class="secondary step-action" id="gps-stop">Stop sharing location</button>':`<label class="check-label"><input id="gps-consent" type="checkbox"> I agree to share my location for this assigned visit.</label><button class="primary step-action" id="gps-start">${view.recoverableError?'Try location sharing again':'Share my live location'}</button>${state.config?.mode==='local_preview'?'<button class="link-button step-action" id="gps-sample">Preview sample GPS (no device location)</button>':''}`}`:''}${!tech&&t.eligible&&!p?'<p class="small muted">The assigned technician can enable GPS from their dashboard. No location is shown until they share it.</p>':''}</section>`;
  }
  function bindGps(b){
    $('gps-start')?.addEventListener('click',async event=>{if(!$('gps-consent')?.checked){notify('Please confirm sharing your location with this customer and PVG admin.');return;}event.currentTarget.disabled=true;await gps.start(b.id);await refreshGps({force:true});});
    $('gps-sample')?.addEventListener('click',async event=>{event.currentTarget.disabled=true;await gps.start(b.id,{sample:true});await refreshGps({force:true});});
    $('gps-stop')?.addEventListener('click',async()=>{await gps.stop();await refreshGps({force:true});});
  }
  function paintGps(b){if($('gps-panel')){$('gps-panel').innerHTML=trackingMarkup(b);bindGps(b);}}
  async function refreshGps({force=false}={}){
    const b=state.currentBooking;if(!state.token||!b||document.hidden||(!force&&$('gps-consent')?.checked))return;
    try{const tracking=await api(`/bookings/${b.id}/tracking`);if(state.currentBooking?.id!==b.id)return;b.tracking=tracking;if(gps.bookingId===b.id){if(!tracking.eligible)await gps.stop();else if(gps.sessionId&&['expired','not_sharing'].includes(tracking.state))await gps.stop('GPS sharing ended. Start sharing again when ready.','error');}paintGps(b);}
    catch(error){if($('gps-status'))$('gps-status').textContent='Could not refresh the location. Last position may be outdated.';}
  }
  $('gps-global-stop').addEventListener('click',async()=>{await gps.stop();await refreshGps({force:true});});
  addEventListener('pagehide',()=>{void gps.stop();});
  document.addEventListener('visibilitychange',()=>{if(document.hidden&&!gps.sample)void gps.stop('Sharing paused because the dashboard was hidden. Start again when ready.');else if(!document.hidden)void refreshGps();});
  setInterval(()=>{if(document.hidden||!state.token)return;void refreshGps();},10000);

  $('staff-login').addEventListener('submit',async event=>{event.preventDefault();const form=event.currentTarget,data=new FormData(form),button=form.querySelector('button'),password=data.get('password');form.elements.password.value='';button.disabled=true;try{await login(data.get('username'),password);}catch(error){$('login-error').textContent=error.message;$('login-error').hidden=false;}finally{button.disabled=false;}});
  for(const role of ['admin','tech'])$(`demo-${role}`).addEventListener('click',async event=>{event.currentTarget.disabled=true;try{const account=state.config.demo_accounts[role==='tech'?'technician':'admin'];await login(account.username,account.password);}catch(error){$('login-error').textContent=error.message;$('login-error').hidden=false;}finally{event.target.disabled=false;}});
  $('mobile-logout').addEventListener('click',()=> $('logout').click());
  $('logout').addEventListener('click',async()=>{try{await api('/auth/logout',{});}finally{signedOut();}});
  $('refresh').addEventListener('click',refresh);
  $('search').addEventListener('input',render);$('status').addEventListener('change',render);
  document.querySelectorAll('[data-view]').forEach(button=>button.addEventListener('click',()=>{state.view=button.dataset.view;render();}));
  addEventListener('pageshow',event=>{if(event.persisted)signedOut();});
  api('/config').then(config=>{
    state.config=config;$('demo-access').hidden=config.mode!=='local_preview';
    if(config.mode==='supabase'){
      document.querySelector('.preview-bar').textContent='PVG OPERATIONS · Live Supabase records · Payments in test mode';
      document.querySelectorAll('a[href="index.html?preview=1"]').forEach(link=>{link.href='https://pvg-ev-dashboard.vercel.app/';link.textContent='Website enquiries ↗';});
    }
  }).catch(error=>{$('login-error').textContent=error.message;$('login-error').hidden=false;});
})();
