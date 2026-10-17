'use strict';
window.PVGFormWizard=function(form){
  const type=form.dataset.form,steps=[...form.querySelectorAll('[data-wizard-step]')];
  const fields=[...form.querySelectorAll('input,select,textarea')],progress=[...form.querySelectorAll('[data-wizard-progress]')];
  const alert=form.querySelector('.wizard-alert'),result=form.querySelector('.form-result'),submit=form.querySelector('[type=submit]');
  const draft=form.querySelector('.wizard-draft'),status=form.querySelector('[data-step-status]');
  const local=['localhost','127.0.0.1','[::1]'].includes(location.hostname),demo=window.PVG_CONFIG?.demo===true;
  const key=`pvg-form-v2:${type}`,storageMode=demo?'demo':local?'local':'live';
  let index=0,reference=null,submissionId=null,submissionData=null,busy=false,locationCapture=null;
  const named=name=>form.elements.namedItem(name);
  const data=()=>Object.fromEntries(fields.filter(f=>f.name&&(!['checkbox','radio'].includes(f.type)||f.checked)).map(f=>[f.name,f.value]));
  const showResult=(title,message)=>{result.hidden=false;result.querySelector('[data-result-title]').textContent=title;result.querySelector('[data-result-message]').textContent=message;result.focus();};
  const setError=(name,message)=>{
    const field=named(name),error=[...form.querySelectorAll('[data-error-for]')].find(e=>e.dataset.errorFor===name);
    if(field){if(message)field.setAttribute('aria-invalid','true');else field.removeAttribute('aria-invalid');}
    if(error){error.textContent=message;error.hidden=!message;}
  };
  const validate=scope=>{
    const errors=PVGForm.errors(data(),type);let first=null;
    for(const field of scope.querySelectorAll('input,select,textarea')){
      if(!field.name||field.type==='hidden'||field.name==='website')continue;
      const message=errors[field.name]||'';setError(field.name,message);if(message)first||=field;
    }
    alert.hidden=!first;
    return first;
  };
  const focusInvalid=field=>{
    const step=field.closest('[data-wizard-step]');if(step)showStep(Number(step.dataset.wizardStep),false);
    const details=field.closest('details');if(details)details.open=true;
    if(field.name==='gps_location')form.querySelector('[data-location]').focus();else field.focus();
    alert.hidden=false;
  };
  const renderReview=()=>{
    const review=form.querySelector('[data-review]');review.replaceChildren();
    for(let i=0;i<steps.length-1;i++){
      const section=document.createElement('section'),header=document.createElement('header'),heading=document.createElement('h3'),edit=document.createElement('button'),dl=document.createElement('dl');
      heading.textContent=progress[i].querySelector('small').textContent;
      edit.type='button';edit.className='text-button';edit.textContent='Edit';edit.setAttribute('aria-label',`Edit ${heading.textContent.toLowerCase()}`);edit.addEventListener('click',()=>showStep(i));
      header.append(heading,edit);section.append(header);
      for(const field of steps[i].querySelectorAll('input,select,textarea')){
        if(!field.name||field.type==='hidden'||!field.value.trim()||(field.type==='checkbox'&&!field.checked))continue;
        const row=document.createElement('div'),term=document.createElement('dt'),value=document.createElement('dd');
        term.textContent=field.dataset.label||field.name;
        value.textContent=field.type==='checkbox'?'Yes':field.tagName==='SELECT'?field.selectedOptions[0]?.textContent||field.value:field.value;
        row.append(term,value);dl.append(row);
      }
      section.append(dl);review.append(section);
    }
  };
  const saveDraft=()=>{
    if(busy)return;
    const values=data();delete values.website;delete values.consent;delete values['consent-to-receive-updates'];
    try{sessionStorage.setItem(key,JSON.stringify({values,index,submissionId,submissionData,mode:storageMode}));draft.hidden=false;draft.querySelector('[data-draft-status]').textContent='Draft saved in this tab.';}catch{/* Forms still work when browser storage is unavailable. */}
  };
  const showStep=(next,focus=true)=>{
    index=Math.max(0,Math.min(next,steps.length-1));
    steps.forEach((s,i)=>{s.hidden=i!==index;s.disabled=i!==index;});
    progress.forEach((p,i)=>{p.classList.toggle('complete',i<index);if(i===index)p.setAttribute('aria-current','step');else p.removeAttribute('aria-current');});
    status.textContent=`Step ${index+1} of ${steps.length}`;
    if(index===steps.length-1)renderReview();
    if(steps[index].querySelector('[data-location]'))locationCapture?.enter();
    alert.hidden=!steps[index].querySelector('[aria-invalid=true]');
    if(focus){const heading=steps[index].querySelector('legend');heading.focus({preventScroll:true});heading.scrollIntoView({block:'start',behavior:'auto'});saveDraft();}
  };
  form.querySelectorAll('[data-next]').forEach(button=>button.addEventListener('click',()=>{if(busy)return;const invalid=validate(steps[index]);if(invalid)focusInvalid(invalid);else showStep(index+1);}));
  form.querySelectorAll('[data-back]').forEach(button=>button.addEventListener('click',()=>{if(!busy)showStep(index-1);}));
  form.addEventListener('keydown',event=>{if(event.key==='Enter'&&event.target.tagName==='INPUT'&&!['checkbox','radio'].includes(event.target.type)&&index<steps.length-1){event.preventDefault();if(!busy)steps[index].querySelector('[data-next]')?.click();}});
  for(const eventName of ['input','change'])form.addEventListener(eventName,event=>{
    if(fields.includes(event.target)){setError(event.target.name,'');alert.hidden=!steps[index].querySelector('[aria-invalid=true]');reference=null;saveDraft();}
  });
  form.querySelector('[data-clear-draft]').addEventListener('click',()=>{
    if(busy)return;form.reset();reference=null;submissionId=null;submissionData=null;locationCapture?.reset();fields.forEach(f=>setError(f.name,''));
    for(const n of ['latitude','longitude','gps_accuracy','gps_location'])if(named(n))named(n).value='';
    try{sessionStorage.removeItem(key);}catch{}
    draft.hidden=true;result.hidden=true;showStep(0,false);steps[0].querySelector('input,select,textarea')?.focus();

  });
  let restored=false;
  try{
    const saved=JSON.parse(sessionStorage.getItem(key)||'null');
    if(saved&&saved.mode===storageMode&&saved.values&&typeof saved.values==='object'){
      for(const field of fields){if(!Object.hasOwn(saved.values,field.name)||['consent','consent-to-receive-updates','website'].includes(field.name))continue;if(field.type==='checkbox')field.checked=saved.values[field.name]==='on';else field.value=String(saved.values[field.name]);}
      index=Number.isInteger(saved.index)?saved.index:0;submissionId=/^[0-9a-f-]{36}$/i.test(saved.submissionId||'')?saved.submissionId:null;submissionData=typeof saved.submissionData==='string'?saved.submissionData:null;restored=true;
    }
  }catch{}
  if(restored){draft.hidden=false;draft.querySelector('[data-draft-status]').textContent='Draft restored. Review before sending.';}
  const params=new URLSearchParams(location.search);
  if(!restored&&type==='contact'){
    const topics={site:'Commercial Charging',partnership:'Partnership / Setrans',general:'General Enquiry',existing:'General Enquiry'};
    if(topics[params.get('topic')])named('requirement').value=topics[params.get('topic')];
  }
  if(!restored&&type==='request'){
    const aliases={mobile:'Mobile EV charging',fleet:'Fleet charging',commercial:'Temporary project location',pilot:'Pilot programme',emergency:'Low battery / stranded vehicle'};
    const value=params.get('type')||params.get('requirement');
    const choice=aliases[value]||value;
    if(PVGForm.schema.request.requirement_type.options.includes(choice))named('requirement_type').value=choice;
  }
  const locationButton=form.querySelector('[data-location]');
  if(locationButton){
    const locationStatus=form.querySelector('[data-location-status]'),clear=form.querySelector('[data-clear-location]');
    const card=form.querySelector('[data-location-card]'),title=form.querySelector('[data-location-title]'),coordinates=form.querySelector('[data-location-coordinates]');
    const clearCoordinates=()=>{for(const name of ['latitude','longitude','gps_location','gps_accuracy'])named(name).value='';clear.hidden=true;coordinates.hidden=true;};
    const feedback={
      idle:['Ready to find your location','GPS is cleared. Choose “Try GPS again” when you are at the charging site.'],
      locating:['Finding your location…','Allow location access in your browser. You can add the address below while we find your GPS pin.'],
      blocked:['Location permission is off','Allow location for this website in your browser settings, then try again. You can also contact our team below.'],
      unsupported:['GPS isn’t available here','Open this form in Safari or Chrome on your phone, or contact our team below.'],
      error:['We couldn’t find your location','Check that Location Services are on and try again, preferably outdoors or near a window.']
    };
    locationCapture=PVGLocation.create(navigator.geolocation,state=>{
      card.dataset.state=state.state;card.setAttribute('aria-busy',String(state.state==='locating'));
      locationButton.disabled=state.state==='locating';locationButton.textContent=state.state==='locating'?'Detecting…':state.state==='captured'?'Update location':'Try GPS again';
      if(state.state==='captured'){
        named('latitude').value=state.latitude.toFixed(6);named('longitude').value=state.longitude.toFixed(6);
        named('gps_location').value=`${state.latitude.toFixed(6)}, ${state.longitude.toFixed(6)}`;named('gps_accuracy').value=state.accuracy===null?'':String(state.accuracy);
        coordinates.hidden=false;clear.hidden=false;title.textContent='Your GPS location is ready';
        locationStatus.textContent=`${state.accuracy===null?'Location captured.':`Accuracy: approximately ${state.accuracy} m.`} Please check that this is the charging site.`;
        setError('gps_location','');alert.hidden=!steps[index].querySelector('[aria-invalid=true]');
      }else{
        clearCoordinates();const text=feedback[state.state]||feedback.error;title.textContent=text[0];locationStatus.textContent=state.reason==='timeout'?'Finding your GPS took too long. Check Location Services and try again.':text[1];
      }
      reference=null;
      if(state.state!=='idle')saveDraft();
    });
    if(named('latitude').value&&named('longitude').value){coordinates.hidden=false;clear.hidden=false;card.dataset.state='captured';title.textContent='Saved GPS location';locationStatus.textContent='We’ll refresh this GPS pin when you open the Location step.';}
    clear.addEventListener('click',()=>{locationCapture.reset(false);reference=null;saveDraft();});
    locationButton.addEventListener('click',()=>locationCapture.retry());
  }
  const note=form.querySelector('.preview-note');
  if(demo||local){note.hidden=false;note.textContent=demo?'Client preview · Try the form. No enquiry will be sent.':'Local preview · Test enquiries stay on this computer.';}
  const setBusy=value=>{busy=value;form.setAttribute('aria-busy',String(value));fields.forEach(f=>f.disabled=value);form.querySelectorAll('button').forEach(b=>b.disabled=value);if(!value)steps.forEach((s,i)=>s.disabled=i!==index);};
  form.addEventListener('submit',async event=>{
    event.preventDefault();if(busy)return;
    if(index<steps.length-1){steps[index].querySelector('[data-next]').click();return;}
    const invalid=validate(form);if(invalid){focusInvalid(invalid);return;}
    const values=data(),error=PVGForm.validate(values,type);
    if(error){showResult('Please check your enquiry',error);return;}
    const record=PVGForm.buildRecord(values,type,null),whatsapp=form.querySelector('[data-whatsapp]');
    const currentData=JSON.stringify(record);
    if(!submissionId||submissionData!==currentData){submissionId=crypto.randomUUID();submissionData=currentData;}
    reference=null;
    saveDraft();setBusy(true);submit.textContent='Sending…';whatsapp.hidden=true;
    let saved=false;
    if(demo){saved=true;reference='PVG-DEMO';showResult('Preview completed','Your form is complete. This client preview did not send an enquiry or save your details to PVG-EV.');}
    else{
      try{
        reference=await PVGSubmit.send(record,submissionId,{config:window.PVG_CONFIG,local});
        saved=true;
      }catch{/* Preserve the enquiry and offer a retry or WhatsApp handoff. */}
      if(local)showResult(saved?'Preview enquiry saved':'Preview save failed',saved?'Your test enquiry was saved on this computer. No enquiry was sent to PVG-EV.':'Your details are still here. Please retry.');
      else{
        whatsapp.href=`https://wa.me/919751083000?text=${encodeURIComponent(PVGForm.message(values,type,reference))}`;whatsapp.hidden=false;
        showResult(saved?'Enquiry received':'Enquiry not saved',saved?'Your details are ready for the team to review. You may also continue in WhatsApp and press Send there. Availability and booking details still need confirmation.':'We could not confirm your enquiry was saved. Retry, or continue in WhatsApp and press Send there.');
      }
    }
    result.querySelector('[data-reference]').textContent=reference?`Reference: ${reference}`:'';
    setBusy(false);
    if(saved){
      try{sessionStorage.removeItem(key);}catch{}
      draft.hidden=true;form.querySelector('[data-wizard-fields]').hidden=true;status.textContent='Complete';alert.hidden=true;
      progress.forEach(p=>{p.classList.add('complete');p.removeAttribute('aria-current');});
    }else submit.textContent='Retry enquiry ↗';
    result.focus();
  });
  showStep(index,false);
};
