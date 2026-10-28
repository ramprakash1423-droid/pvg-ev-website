/* Shared display and local preview logic. Live authorization belongs in Supabase. */
(function(root){
  const types={request:'EV charging',fleet:'Fleet enquiry',contact:'Contact message',pilot:'Pilot programme'};
  const statuses={new:'New',reviewing:'Reviewing',contacted:'Contacted',closed:'Closed',spam:'Spam'};
  const pageSize=20;
  function dateStart(value,now=new Date()){
    if(value==='today'){
      const indiaDate=new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Kolkata',year:'numeric',month:'2-digit',day:'2-digit'}).format(now);
      return new Date(`${indiaDate}T00:00:00+05:30`).toISOString();
    }
    return ['7','30'].includes(value)?new Date(now.getTime()-Number(value)*86400000).toISOString():null;
  }
  function query(records,{search='',type='all',status='all',since=null,offset=0,limit=pageSize}={}){
    const stats={total:records.length,new:0,active:0,closed:0};
    records.forEach(r=>{if(r.status==='new')stats.new++;if(['reviewing','contacted'].includes(r.status))stats.active++;if(r.status==='closed')stats.closed++;});
    const term=String(search).trim().slice(0,120).toLocaleLowerCase();
    const matches=records.filter(r=>
      (type==='all'||r.form_type===type)&&
      (status==='all'||(status==='active'?['reviewing','contacted'].includes(r.status):r.status===status))&&
      (!since||Date.parse(r.created_at)>=Date.parse(since))&&
      (!term||[r.name,r.phone,r.email,r.company,r.reference,r.city,r.requirement_type].some(v=>String(v||'').toLocaleLowerCase().includes(term)))
    ).sort((a,b)=>Date.parse(b.created_at)-Date.parse(a.created_at)||String(b.id).localeCompare(String(a.id)));
    const start=Math.max(0,Math.floor(Number(offset)||0)),count=Math.max(1,Math.min(50,Math.floor(Number(limit)||pageSize)));
    return {records:matches.slice(start,start+count),total:matches.length,stats};
  }
  function mapUrl(record){
    const latitude=record.latitude??record.payload?.latitude,longitude=record.longitude??record.payload?.longitude;
    if(latitude==null||longitude==null||latitude===''||longitude==='')return null;
    const lat=Number(latitude),lon=Number(longitude);
    return Number.isFinite(lat)&&Number.isFinite(lon)&&Math.abs(lat)<=90&&Math.abs(lon)<=180?`https://www.google.com/maps/search/?api=1&query=${lat},${lon}`:null;
  }
  function phoneDigits(value){const digits=String(value||'').replace(/\D/g,'');return /^\d{10}$/.test(digits)?'91'+digits:/^91\d{10}$/.test(digits)?digits:null;}
  function displayValue(value){return Array.isArray(value)?value.map(displayValue).join(', '):typeof value==='boolean'?(value?'Yes':'No'):value&&typeof value==='object'?JSON.stringify(value):String(value??'');}
  function fields(record,schema={}){
    const values={...record.payload};
    // Include saved columns that may not have been present in older form payloads.
    const skip=new Set(['id','reference','source','form_type','payload','status','created_at','updated_at','saved_at','website','preview']);
    const aliases={requirement_type:['requirement','main-charging-challenge'],customer_type:['customer-type'],use_case:['expected-use-case'],phone:['telephone'],address:['operating-base','preferred-pilot-location','preferred-charging-location'],vehicle_category:['vehicle-types','fleet-type'],vehicle_count:['number-of-evs'],charging_need:['current-charging-method'],charging_details:['additional_notes','additional-notes'],preferred_window:['charging-window','expected-charging-frequency','fleet-operating-hours'],target_date:['preferred_date'],preferred_time:['contact_time'],message:['additional_notes','additional-notes']};
    const hasValue=key=>values[key]!==undefined&&values[key]!==null&&values[key]!=='';
    for(const [key,value] of Object.entries(record))if(!skip.has(key)&&!hasValue(key)&&!(aliases[key]||[]).some(hasValue))values[key]=value;
    return Object.entries(values).filter(([key,value])=>!skip.has(key)&&value!==null&&value!==undefined&&value!=='')
      .map(([key,value])=>({label:schema[record.form_type]?.[key]?.label||key.replace(/[_-]/g,' ').replace(/^./,c=>c.toUpperCase()),value:displayValue(value)}));
  }
  const api={types,statuses,pageSize,dateStart,query,mapUrl,phoneDigits,displayValue,fields};
  if(typeof module==='object'&&module.exports)module.exports=api;else root.PVGDashboard=api;
})(typeof globalThis!=='undefined'?globalThis:this);
