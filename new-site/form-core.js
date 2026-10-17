/* Shared validation and database mapping for every PVG enquiry form. */
(function(root,factory){
  if(typeof module==='object'&&module.exports)module.exports=factory(require('./form-schema.js'));
  else root.PVGForm=factory(root.PVGFormSchema);
})(typeof globalThis!=='undefined'?globalThis:this,function(schema){
  'use strict';
  const trim=value=>String(value??'').trim();
  const first=(data,names)=>names.map(name=>trim(data[name])).find(Boolean)||'';
  const yes=value=>value===true||value==='on'||value==='yes';
  function normalizePhone(value){const n=trim(value).replace(/[\s()+-]/g,'');return /^91[6-9]\d{9}$/.test(n)?n.slice(2):n;}
  function errors(data,type){
    const result={};
    if(!schema[type])return {form:'Unknown enquiry type.'};
    for(const [name,field] of Object.entries(schema[type])){
      if(['website','latitude','longitude','gps_accuracy'].includes(name))continue;
      const value=trim(data[name]);
      if(field.required&&(field.type==='checkbox'?!yes(data[name]):!value)){
        result[name]=field.type==='checkbox'?'Please confirm before sending.':`Please enter or choose ${field.label.toLowerCase()}.`;continue;
      }
      if(!value)continue;
      if(field.type==='email'&&!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value))result[name]='Enter a valid email address.';
      if(field.type==='tel'&&!/^[6-9]\d{9}$/.test(normalizePhone(value)))result[name]='Enter a valid 10-digit Indian mobile number.';
      if(field.type==='number'){
        const n=Number(value),min=Number(field.min??0),max=Number(field.max??100000);
        if(!Number.isInteger(n)||n<min||n>max)result[name]=`Enter a whole number from ${min} to ${max}.`;
      }
      if(field.options&&!field.options.includes(value))result[name]='Choose an option from the list.';
      if(field.type==='date'&&(!/^\d{4}-\d{2}-\d{2}$/.test(value)||!Number.isFinite(Date.parse(value))||new Date(value).toISOString().slice(0,10)!==value))result[name]='Choose a valid date.';
      if(field.type==='time'&&!/^([01]\d|2[0-3]):[0-5]\d$/.test(value))result[name]='Choose a valid time.';
      if(value.length>(field.type==='textarea'?2000:200))result[name]='Please shorten this entry.';
    }
    if(type==='request'){
      const lat=trim(data.latitude),lon=trim(data.longitude);
      if(!lat||!lon||!Number.isFinite(Number(lat))||!Number.isFinite(Number(lon))||Math.abs(Number(lat))>90||Math.abs(Number(lon))>180||!trim(data.gps_location))result.gps_location='Capture your GPS location to continue, or contact the team for help.';
      if(trim(data.gps_accuracy)&&(!Number.isFinite(Number(data.gps_accuracy))||Number(data.gps_accuracy)<0))result.gps_location='Please capture your GPS location again.';
    }
    if(trim(data.website))result.website='We could not accept this enquiry. Please contact the team.';
    return result;
  }
  const validate=(data,type)=>Object.values(errors(data,type))[0]||'';
  const interests=data=>Object.entries(schema.pilot).filter(([key])=>key.startsWith('interested-in-')&&yes(data[key])).map(([,field])=>field.label);
  function buildRecord(data,type,reference){
    const value=names=>first(data,names)||null;
    const number=name=>trim(data[name])===''?null:Number(data[name]);
    const payload={...data,consent:yes(data.consent)||yes(data['consent-to-receive-updates']),consent_version:'2026-10-15'};
    delete payload.website;
    return {
      reference,source:'pvg_ev_website',form_type:type,status:'new',
      requirement_type:value(type==='request'?['requirement_type']:type==='fleet'?['main-charging-challenge']:type==='contact'?['requirement']:[])||(type==='pilot'?'Pilot programme':type),
      customer_type:value(['customer_type','customer-type']),requirement_scope:value(['requirement_scope']),
      priority:value(['priority']),use_case:value(['expected-use-case']),
      phone:normalizePhone(first(data,['phone','telephone'])),name:value(['name']),email:value(['email']),company:value(['company']),city:value(['city']),
      location_type:value(['location_type']),address:value(['address','operating-base','preferred-pilot-location','preferred-charging-location']),
      gps_location:value(['gps_location']),latitude:number('latitude'),longitude:number('longitude'),gps_accuracy:number('gps_accuracy')===null?null:Math.round(number('gps_accuracy')),
      vehicle_category:value(['vehicle_category','vehicle-types','fleet-type']),vehicle_model:value(['vehicle_model']),vehicle_count:value(['vehicle_count','number-of-evs']),
      connector_type:value(['connector_type']),battery_status:value(['battery_status']),current_battery_level:value(['current_battery_level']),charging_need:value(['charging_need','current-charging-method']),
      charging_details:value(['charging_details','additional_notes','additional-notes']),preferred_window:value(['preferred_window','charging-window','expected-charging-frequency','fleet-operating-hours']),
      target_date:value(['target_date','preferred_date']),preferred_time:value(['preferred_time','contact_time']),
      pilot_interest:type==='pilot'?(interests(data).join('; ')||null):value(['pilot_interest']),message:value(['message','additional_notes','additional-notes']),payload
    };
  }
  function message(data,type,reference){
    const lines=[`PVG-EV ${type} enquiry`,`Reference: ${reference}`];
    for(const [name,field] of Object.entries(schema[type])){
      if(['website','latitude','longitude','gps_accuracy','consent','consent-to-receive-updates'].includes(name))continue;
      if(field.type==='checkbox'){if(yes(data[name]))lines.push(`${field.label}: Yes`);}
      else if(trim(data[name]))lines.push(`${field.label}: ${trim(data[name])}`);
    }
    if(trim(data.latitude)!==''&&trim(data.longitude)!=='')lines.push(`GPS map: https://maps.google.com/?q=${Number(data.latitude)},${Number(data.longitude)}`);
    if(trim(data.gps_accuracy))lines.push(`GPS accuracy: approximately ${Math.round(Number(data.gps_accuracy))} metres`);
    lines.push('I agree to be contacted about this enquiry. Service is subject to confirmation.');
    return lines.join('\n');
  }
  return {normalizePhone,errors,validate,buildRecord,message,schema};
});
