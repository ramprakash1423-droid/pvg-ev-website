'use strict';
document.documentElement.classList.add('js');
const localPreview=['localhost','127.0.0.1','[::1]'].includes(location.hostname);
const menu=document.querySelector('.menu-toggle');
const navigation=document.getElementById('primary-nav');
if(menu&&navigation){
  menu.hidden=false;
  const close=()=>{menu.setAttribute('aria-expanded','false');navigation.classList.remove('open');};
  menu.addEventListener('click',()=>{const open=menu.getAttribute('aria-expanded')!=='true';menu.setAttribute('aria-expanded',String(open));navigation.classList.toggle('open',open);});
  document.addEventListener('keydown',event=>{if(event.key==='Escape'&&menu.getAttribute('aria-expanded')==='true'){close();menu.focus();}});
  navigation.addEventListener('click',event=>{if(event.target.closest('a'))close();});
}
document.querySelectorAll('[data-print]').forEach(button=>button.addEventListener('click',()=>window.print()));
const search=document.getElementById('insight-search');
const category=document.getElementById('insight-category');
if(search&&category){
  const filter=()=>{const query=search.value.toLocaleLowerCase().trim();let count=0;
    document.querySelectorAll('[data-article]').forEach(article=>{const match=article.dataset.search.toLocaleLowerCase().includes(query)&&(category.value==='all'||article.dataset.category===category.value);article.hidden=!match;if(match)count++;});
    document.getElementById('search-status').textContent=`${count} practical ${count===1?'brief':'briefs'}`;
    document.getElementById('no-results').hidden=count>0;
  };
  search.form.addEventListener('submit',event=>event.preventDefault());search.addEventListener('input',filter);category.addEventListener('change',filter);
}
for(const form of document.querySelectorAll('[data-form]')){
  if(form.classList.contains('pvg-wizard')){window.PVGFormWizard(form);continue;}
  const type=form.dataset.form;
  const result=form.querySelector('.form-result');
  const submit=form.querySelector('[type=submit]');
  const whatsapp=form.querySelector('[data-whatsapp]');
  const submitArea=form.querySelector('[data-submit-area]');
  const steps=[...form.querySelectorAll('[data-step]')];
  const friendly=form.hasAttribute('data-friendly')?window.PVGRequestForm?.(form):null;
  let reference=null,locationAttempt=0;
  const showResult=(title,message)=>{result.hidden=false;result.querySelector('[data-result-title]').textContent=title;result.querySelector('[data-result-message]').textContent=message;result.focus();};
  const setStep=number=>{steps.forEach(fieldset=>{fieldset.hidden=Number(fieldset.dataset.step)!==number;fieldset.disabled=fieldset.hidden;});submitArea.hidden=number!==2;form.querySelectorAll('[data-progress]').forEach(item=>{if(Number(item.dataset.progress)===number)item.setAttribute('aria-current','step');else item.removeAttribute('aria-current');});friendly?.setStep(number);};
  const validFields=container=>{if(friendly){const invalid=friendly.validate(container);if(invalid){invalid.focus();return false;}return true;}for(const field of container.querySelectorAll('input,select,textarea'))if(!field.checkValidity()){field.reportValidity();return false;}return true;};
  if(steps.length){
    setStep(1);
    const next=()=>{const phone=form.elements.phone;phone.setCustomValidity(/^[6-9]\d{9}$/.test(PVGForm.normalizePhone(phone.value))?'':'Enter a valid 10-digit Indian mobile number.');if(validFields(steps[0])){setStep(2);const target=steps[1].querySelector(friendly?'legend':'input,select,textarea');target.focus();if(friendly)target.scrollIntoView({block:'start'});}};
    form.querySelector('.step-next').addEventListener('click',next);
    form.querySelector('.step-back').addEventListener('click',()=>{setStep(1);steps[0].querySelector('input').focus();});
    steps[0].addEventListener('keydown',event=>{if(event.key==='Enter'&&event.target.tagName==='INPUT'){event.preventDefault();next();}});
  }
  form.elements.phone.addEventListener('input',()=>form.elements.phone.setCustomValidity(''));
  if(localPreview)form.querySelector('.preview-note').hidden=false;
  const consentHelp=form.querySelector('[data-consent-help]');
  consentHelp.hidden=true;
  if(type==='pilot'){
    const interest=form.elements.pilot_interest,details=form.querySelector('[data-pilot-details]');
    const sync=()=>{const updates=interest.value==='updates';details.hidden=updates;details.querySelectorAll('input,textarea').forEach(field=>field.disabled=updates);consentHelp.hidden=!updates;form.elements.city.required=!updates;};
    interest.addEventListener('change',sync);sync();
  }
  if(type==='contact'){
    const topic=new URLSearchParams(location.search).get('topic');
    if([...form.elements.topic.options].some(o=>o.value===topic))form.elements.topic.value=topic;
  }
  const locationButton=form.querySelector('[data-location]');
  if(locationButton){
    const status=form.querySelector('#location-status'),clear=form.querySelector('[data-clear-location]');
    clear.addEventListener('click',()=>{locationAttempt++;form.elements.latitude.value='';form.elements.longitude.value='';clear.hidden=true;locationButton.disabled=false;status.textContent='GPS removed. Your address or maps link will be used.';});
    locationButton.addEventListener('click',()=>{
      if(!navigator.geolocation){status.textContent='Location is unavailable. Enter the address or maps link above.';return;}
      const attempt=++locationAttempt;locationButton.disabled=true;status.textContent='Waiting for location permission…';
      navigator.geolocation.getCurrentPosition(position=>{if(attempt!==locationAttempt)return;form.elements.latitude.value=position.coords.latitude.toFixed(6);form.elements.longitude.value=position.coords.longitude.toFixed(6);locationButton.disabled=false;clear.hidden=false;status.textContent='Current GPS added. Keep the charging address above so the team can verify the site.';},()=>{if(attempt!==locationAttempt)return;locationButton.disabled=false;status.textContent='Location was not shared. You can continue with the address or maps link.';},{enableHighAccuracy:false,timeout:10000,maximumAge:60000});
    });
  }
  form.addEventListener('submit',async event=>{
    event.preventDefault();
    // First-step fields are visually hidden, but included in the complete enquiry.
    steps.forEach(step=>step.disabled=false);
    if(friendly){
      const invalid=friendly.validate(form);
      if(invalid){const step=invalid.closest('[data-step]');if(step)setStep(Number(step.dataset.step));steps.forEach(item=>item.disabled=item.hidden);invalid.focus();return;}
    }
    const data=Object.fromEntries(new FormData(form));
    if(steps.length)steps.forEach(step=>step.disabled=step.hidden);
    const error=PVGForm.validate(data,type);
    if(error){showResult('Please check your details',error);return;}
    submit.disabled=true;submit.textContent='Submitting…';whatsapp.hidden=true;
    reference ||= `PVG-${Date.now()}-${crypto.randomUUID().slice(0,8).toUpperCase()}`;
    const record=PVGForm.buildRecord(data,type,reference);
    let saved=false;
    try{
      const config=window.PVG_CONFIG;
      const response=await fetch(localPreview?'/__preview/enquiries':`${config.url.replace(/\/$/,'')}/rest/v1/pvg_ev_charging_requests`,{
        method:'POST',headers:localPreview?{'Content-Type':'application/json'}:{'Content-Type':'application/json',apikey:config.key,Authorization:`Bearer ${config.key}`,Prefer:'return=minimal'},body:JSON.stringify(record),signal:AbortSignal.timeout(10000)
      });
      // A reused reference is idempotent: the original enquiry already exists.
      if(response.ok)saved=true;
      else if(response.status===409){const detail=await response.json();saved=detail.code==='23505';}
    }catch{/* Keep the enquiry on the page and offer an explicit alternate route. */}
    result.querySelector('[data-reference]').textContent=`Reference: ${reference}`;
    if(localPreview){
      showResult(saved?'Preview enquiry saved':'Preview save failed',saved?'Your test enquiry was saved on this computer. No message was sent to PVG-EV.':'Your details are still here. Check that the local preview server is running and try again.');
    }else{
      whatsapp.href=`https://wa.me/919751083000?text=${encodeURIComponent(PVGForm.message(data,type,reference))}`;whatsapp.hidden=false;
      showResult(saved?'Enquiry received':'Enquiry not saved',saved?'Your enquiry is ready for the team to review. You may also continue in WhatsApp. Availability and booking details still need confirmation.':'We could not confirm that your enquiry was saved. Continue in WhatsApp and press Send there, or retry this form. Keep your reference so the team can avoid duplicates.');
    }
    submit.disabled=saved;submit.textContent=saved?'Enquiry submitted':'Retry enquiry';
    if(saved){form.querySelectorAll('input,select,textarea,.step-next,.step-back,[data-location],[data-clear-location]').forEach(control=>control.disabled=true);friendly?.complete();result.focus();}
  });
}
