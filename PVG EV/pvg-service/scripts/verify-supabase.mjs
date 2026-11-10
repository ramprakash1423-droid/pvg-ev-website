// Contract verification runs inside one rolled-back transaction. No sample rows are retained.
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {PostgresDatabase} from '../src/postgres.mjs';
import {PostgresStore} from '../src/postgres-store.mjs';
import {CustomerExperience} from '../src/customer-experience.mjs';
import {ApiError} from '../src/domain.mjs';
const config=JSON.parse(await readFile(new URL('../.local/supabase.json',import.meta.url),'utf8'));
const db=new PostgresDatabase(config.database_url),s=new PostgresStore(db);
const rollback=new Error('verification complete; roll back');
let checks=0;function check(actual,expected){assert.deepEqual(actual,expected);checks++;}
async function rejects(fn,status){await assert.rejects(fn,e=>e instanceof ApiError&&e.status===status);checks++;}
try{
 const before=await db.prepare('SELECT count(*) AS n FROM bookings').get();
 try{await db.tx(async()=>{
  for(const [id,role]of [['verify-customer','customer'],['verify-other','customer'],['verify-tech','technician'],['verify-admin','admin']])await db.prepare('INSERT INTO users(id,name,role) VALUES(?,?,?)').run(id,'Rollback verification',role);
  const c=await s.user('verify-customer'),other=await s.user('verify-other'),tech=await s.user('verify-tech'),admin=await s.user('verify-admin');
  const experience=new CustomerExperience(s);
  const tomorrow=new Date(Date.now()+86400000+330*60000).toISOString().slice(0,10);
  const visitTime=`${tomorrow}T10:00:00+05:30`;
  await experience.saveSettings(admin,{open_minutes:360,close_minutes:1380,visit_minutes:120,pincodes:['600020']});
  check((await experience.availability({pincode:'600020'})).state,'confirmation_required');
  await experience.draft(c,{address:'Rollback-only draft',request_key:'rollback-draft'});
  check((await experience.draft(c)).address,'Rollback-only draft');
  check(await experience.draft(other),{});
  const ev=await s.addEv(c,{model:'Verification EV',registration:'VERIFY',connector:'CCS2'});
  const fleet=await s.addFleet(admin,{name:'Rollback vehicle',registration:'VERIFY 1',compatibility:'CCS2'});
  let b=await s.createBooking(c,{vehicle_id:ev.id,address:'Rollback-only verification address',pincode:'600020',slot:visitTime,request_key:'rollback-verification-001'});
  check(b.estimate,null);check(b.tariff.unit_rate_paise,2000);check(b.reading,null);check(b.invoice,null);check(b.is_demo,false);check(b.tracking.state,'awaiting_assignment');
  await rejects(()=>s.detail(other,b.id),404);
  b=await s.assign(admin,b.id,{version:b.version,technician_id:tech.id,fleet_id:fleet.id,slot:b.slot,compatibility_confirmed:true});
  b=await experience.support(c,b.id,{version:b.version,category:'arrival',message:'Please confirm our arrival window.'});
  check(b.support_request.status,'open');
  await rejects(()=>experience.support(other,b.id,{version:b.version,category:'other',message:'Not my visit'}),404);
  b=await experience.support(admin,b.id,{version:b.version,status:'resolved',message:'We have confirmed the requested visit.'});
  check(b.support_request.status,'resolved');
  b=await experience.reschedule(c,b.id,{version:b.version,slot:visitTime});
  check(b.status,'requested');check(b.technician,null);check(b.fleet_id,null);
  b=await s.assign(admin,b.id,{version:b.version,technician_id:tech.id,fleet_id:fleet.id,slot:b.slot,compatibility_confirmed:true});
  b=await experience.serviceUpdate(tech,b.id,{version:b.version,message:'Your technician is preparing for departure.'});
  check(b.service_note.message,'Your technician is preparing for departure.');
  check(b.fleet_registration,'VERIFY 1');check(b.technician.name,tech.name);
  await rejects(()=>s.startTracking(tech,b.id,{consent:true,source:'sample'}),403);
  await rejects(()=>s.startTracking(tech,b.id,{consent:false}),400);
  const tracking=await s.startTracking(tech,b.id,{consent:true});
  check(tracking.tracking.state,'waiting');
  const p={session_id:tracking.session_id,latitude:13,longitude:80,accuracy:9,captured_at:new Date().toISOString()};
  const gps=await s.updateTracking(tech,b.id,p);check(gps.source,'device');check(gps.position.latitude,13);
  check((await s.row(b.id)).version,b.version);
  await rejects(()=>s.updateTracking(other,b.id,p),403);
  await rejects(()=>s.updateTracking(tech,b.id,{...p,captured_at:new Date(Date.now()-70000).toISOString()}),400);
  for(const status of ['on_the_way','arrived','charging'])b=await s.progress(tech,b.id,{version:b.version,status});
  const photo='data:image/png;base64,'+(await readFile(new URL('../fixtures/demo-meter.png',import.meta.url))).toString('base64');
  b=await s.submitReading(tech,b.id,{version:b.version,kind:'session',units:'15',photo});
  check(b.status,'awaiting_acceptance');check(b.tracking.position,null);
  await rejects(()=>s.accept(other,b.id,{version:b.version,accepted:true,reading_id:b.reading.id,total_paise:70800}),404);
  b=await s.accept(c,b.id,{version:b.version,accepted:true,reading_id:b.reading.id,total_paise:70800});
  check(b.status,'awaiting_payment');check(b.invoice.is_demo,false);check(b.invoice.bill.total_paise,70800);
  const order=await s.paymentOrder(c,b.id);check(order.amount_paise,70800);
  await s.paymentEvent({id:'rollback-payment',type:'payment.captured',order_id:order.id,amount_paise:70800,currency:'INR'});
  check((await s.detail(c,b.id)).status,'paid');
  const place=await s.savePlace(c,{label:'Verification',address:'Rollback-only address',pincode:'600020'});check((await s.places(c))[0].id,place.id);
  await rejects(()=>s.savePlace(other,{label:'Bad',address:'Not an owner address',pincode:'600020'},place.id),404);
  const session=await s.newSession(c);check(session.expires_in,604800);check((await s.authenticate(session.token)).id,c.id);await s.logout(session.token);await rejects(()=>s.authenticate(session.token),401);
  throw rollback;
 });}catch(error){if(error!==rollback)throw error;}
 check((await db.prepare('SELECT count(*) AS n FROM bookings').get()).n,before.n);
 console.log(`Supabase workflow verified: ${checks} checks passed; verification records rolled back.`);
}catch(error){console.error({error:error.code||error.name,message:error.message,stack:error.stack?.split('\n').slice(1,5).join('\n')});process.exitCode=1;}finally{await db.close();}
