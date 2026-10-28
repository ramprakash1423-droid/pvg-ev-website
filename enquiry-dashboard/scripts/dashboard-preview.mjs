import {readFile,mkdir,writeFile,rename} from 'node:fs/promises';
import {dirname} from 'node:path';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const {query,statuses}=require('../dashboard-core.js');
export function previewAllowed(req,port){
 const allowed=[`localhost:${port}`,`127.0.0.1:${port}`];
 return allowed.includes(req.headers.host)&&req.headers['x-pvg-preview']==='dashboard'&&
  (!req.headers.origin||allowed.map(host=>`http://${host}`).includes(req.headers.origin))&&
  (!req.headers['sec-fetch-site']||['same-origin','none'].includes(req.headers['sec-fetch-site']));
}
export function samples(now=new Date()){
 const ago=hours=>new Date(now.getTime()-hours*3600000).toISOString();
 const entries=[
  {name:'Arjun Kumar',form_type:'request',requirement_type:'Mobile EV charging',city:'Adyar, Chennai',address:'Sample address · Adyar, Chennai',vehicle_category:'Electric car',vehicle_model:'Tata Nexon EV',current_battery_level:'18',preferred_window:'Today, 4–6 pm',status:'new',latitude:13.0067,longitude:80.257,gps_accuracy:25,message:'I need a top-up before an evening trip. The vehicle is parked with easy access.',hours:1},
  {name:'Meera Iyer',form_type:'fleet',company:'Southline Logistics · sample',requirement_type:'Fleet charging',city:'Guindy, Chennai',vehicle_category:'Electric van',vehicle_count:'12',preferred_window:'Overnight charging',status:'new',message:'We are exploring charging support for 12 delivery vans. Please call to discuss the daily operating schedule.',hours:3},
  {name:'Vikram Shah',form_type:'pilot',company:'Marina Residences · sample',requirement_type:'Residential or community requirement',city:'Thiruvanmiyur, Chennai',vehicle_count:'8',pilot_interest:'Apartment community',status:'reviewing',message:'Our community would like to understand the pilot and the space needed for mobile charging.',hours:6},
  {name:'Priya Raman',form_type:'contact',requirement_type:'Partnership enquiry',city:'Chennai',status:'new',message:'We would like to discuss charging support at our upcoming sustainability event.',hours:22},
  {name:'Rohit Menon',form_type:'request',requirement_type:'Mobile EV charging',city:'Velachery, Chennai',vehicle_model:'MG ZS EV',current_battery_level:'32',status:'contacted',message:'Looking for a scheduled top-up at our office parking area.',hours:28},
  {name:'Ananya Rao',form_type:'fleet',company:'CityRoute Mobility · sample',requirement_type:'Depot support',city:'Ambattur, Chennai',vehicle_count:'20',status:'closed',message:'Initial fleet enquiry reviewed. This is a sample of a completed follow-up.',hours:50}
 ];
 return entries.map((entry,index)=>{const {hours,...record}=entry;const created_at=ago(hours);return {...record,id:`00000000-0000-4000-8000-00000000000${index+1}`,reference:`PVG-${1048-index}`,phone:`900000000${index+1}`,email:`sample${index+1}@example.com`,created_at,updated_at:created_at,payload:{...record,phone:`900000000${index+1}`,email:`sample${index+1}@example.com`,consent:true,consent_version:'2026-10-15'}};});
}
export async function createPreviewDashboard({file,localRecords,now}){
 const sampleRecords=samples(now);let updates={};let queue=Promise.resolve();
 try{updates=JSON.parse(await readFile(file,'utf8'));}catch(error){if(error.code!=='ENOENT')throw error;}
 const records=source=>(source==='sample'?sampleRecords:localRecords()).map(r=>({...r,status:r.status||'new',created_at:r.created_at||r.saved_at,updated_at:r.updated_at||r.saved_at,...updates[`${source}:${r.id}`]}));
 return async(req,res,url)=>{
  const json=(status,body)=>res.writeHead(status,{'Content-Type':'application/json','Cache-Control':'no-store','X-Content-Type-Options':'nosniff'}).end(JSON.stringify(body));
  if(req.method==='GET'){
   const params=Object.fromEntries(url.searchParams);if(!['sample','local'].includes(params.source))return json(400,{error:'Invalid source'});
   return json(200,query(records(params.source),params));
  }
  if(req.method!=='PATCH'){res.setHeader('Allow','GET, PATCH');return json(405,{error:'Method not allowed'});}
  let body='';for await(const chunk of req){body+=chunk;if(body.length>2000)return json(413,{error:'Too large'});}
  const {source,id,status,expected_updated_at}=JSON.parse(body);
  if(!['sample','local'].includes(source)||!Object.hasOwn(statuses,status)||typeof expected_updated_at!=='string')return json(400,{error:'Invalid status change'});
  const result=await(queue=queue.catch(()=>{}).then(async()=>{
   const record=records(source).find(r=>r.id===id);if(!record)return {code:404,error:'Enquiry not found'};
   if(record.updated_at!==expected_updated_at)return {code:409,error:'Enquiry changed'};
   const updated_at=new Date(Math.max(Date.now(),Date.parse(record.updated_at)+1)).toISOString();
   const next={...updates,[`${source}:${id}`]:{status,updated_at}};
   await mkdir(dirname(file),{recursive:true});await writeFile(file+'.tmp',JSON.stringify(next),{mode:0o600});await rename(file+'.tmp',file);updates=next;return {code:200,saved:true,status,updated_at};
  }));return json(result.code,result);
 };
}
