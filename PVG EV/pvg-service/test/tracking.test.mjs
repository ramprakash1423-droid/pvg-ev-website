import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {Store,ApiError} from '../src/domain.mjs';
import {createApplication} from '../src/server.mjs';
const photo='data:image/png;base64,'+readFileSync(new URL('../fixtures/demo-meter.png',import.meta.url)).toString('base64');
const fails=(fn,status)=>assert.throws(fn,error=>error instanceof ApiError&&error.status===status);
function assigned(store){
  const customer=store.user('customer-demo'),tech=store.user('tech-arun'),admin=store.user('admin-demo');
  const b=store.createBooking(customer,{vehicle_id:store.evs(customer)[0].id,address:'Synthetic GPS test address, Chennai',pincode:'600020',estimated_kwh:'15',slot:new Date(Date.now()+3*86400000).toISOString(),request_key:'gps-test-booking'});
  const booking=store.assign(admin,b.id,{version:b.version,technician_id:tech.id,fleet_id:'vehicle-1',slot:b.slot,compatibility_confirmed:true});
  return {store,customer,tech,admin,booking,other:store.user('customer-other'),otherTech:store.user('tech-meera')};
}
function fixture(t){const store=new Store();store.seed(photo);t.after(()=>store.close());return assigned(store);}
const point=session=>({session_id:session,latitude:13.0188,longitude:80.255,accuracy:12,captured_at:new Date(Date.now()-1000).toISOString()});

test('GPS is assignment scoped, requires consent and cannot mutate booking versions',t=>{
  const f=fixture(t),{store:s,booking:b,tech}=f;
  fails(()=>s.startTracking(f.customer,b.id,{consent:true}),403);
  fails(()=>s.startTracking(f.admin,b.id,{consent:true}),403);
  fails(()=>s.startTracking(f.otherTech,b.id,{consent:true}),404);
  fails(()=>s.tracking(f.other,b.id),404);
  fails(()=>s.startTracking(tech,b.id,{consent:false}),400);
  const {session_id}=s.startTracking(tech,b.id,{consent:true});
  assert.equal(s.tracking(f.customer,b.id).state,'waiting');
  const result=s.updateTracking(tech,b.id,point(session_id));
  assert.equal(result.state,'live');assert.equal(result.position.accuracy,12);
  assert.equal(s.detail(f.customer,b.id).tracking.position.latitude,13.0188);
  assert.equal(s.detail(f.admin,b.id).tracking.source,'device');
  assert.equal(s.row(b.id).version,b.version);
  fails(()=>s.updateTracking(f.otherTech,b.id,point(session_id)),404);
  fails(()=>s.updateTracking(f.customer,b.id,point(session_id)),403);
});
test('GPS rejects inaccurate, invalid, cached, future and out-of-order positions',t=>{
  const {store:s,tech,booking:b}=fixture(t),{session_id}=s.startTracking(tech,b.id,{consent:true}),p=point(session_id);
  for(const values of [{latitude:Infinity},{longitude:181},{accuracy:501},{accuracy:-1},{captured_at:'bad'},{captured_at:new Date(Date.now()-61000).toISOString()},{captured_at:new Date(Date.now()+6000).toISOString()}])fails(()=>s.updateTracking(tech,b.id,{...p,...values}),400);
  s.updateTracking(tech,b.id,p);
  fails(()=>s.updateTracking(tech,b.id,{...p,captured_at:new Date(Date.now()-5000).toISOString()}),409);
  assert.equal(s.updateTracking(tech,b.id,p).position.captured_at,p.captured_at);
});
test('old devices cannot resume or stop a replacement sharing session',t=>{
  const {store:s,tech,customer,booking:b}=fixture(t),first=s.startTracking(tech,b.id,{consent:true}),second=s.startTracking(tech,b.id,{consent:true});
  fails(()=>s.updateTracking(tech,b.id,point(first.session_id)),409);
  s.stopTracking(tech,b.id,first);assert.equal(s.tracking(customer,b.id).state,'waiting');
  s.updateTracking(tech,b.id,point(second.session_id));s.stopTracking(tech,b.id,second);
  assert.equal(s.tracking(customer,b.id).position,null);assert.equal(s.db.prepare('SELECT count(*) n FROM booking_tracking').get().n,0);
  fails(()=>s.updateTracking(tech,b.id,point(second.session_id)),409);
});
test('stale coordinates are labelled and abandoned sharing expires',t=>{
  const {store:s,tech,customer,booking:b}=fixture(t),session=s.startTracking(tech,b.id,{consent:true});
  const p=point(session.session_id);s.updateTracking(tech,b.id,p);
  s.db.prepare('UPDATE booking_tracking SET point=? WHERE booking_id=?').run(JSON.stringify({...p,captured_at:new Date(Date.now()-91000).toISOString()}),b.id);
  assert.equal(s.tracking(customer,b.id).state,'stale');
  s.db.prepare('UPDATE booking_tracking SET point=? WHERE booking_id=?').run(JSON.stringify({...p,captured_at:new Date(Date.now()-901000).toISOString()}),b.id);
  assert.equal(s.tracking(customer,b.id).state,'expired');assert.equal(s.tracking(customer,b.id).position,null);
  fails(()=>s.updateTracking(tech,b.id,point(session.session_id)),409);
});
test('assignment changes, cancellation, sign-out and completion remove GPS',t=>{
  const f=fixture(t),{store:s,booking:b,tech,admin,customer}=f;
  let session=s.startTracking(tech,b.id,{consent:true});s.updateTracking(tech,b.id,point(session.session_id));
  const reassigned=s.assign(admin,b.id,{version:b.version,technician_id:f.otherTech.id,fleet_id:'vehicle-2',slot:b.slot,compatibility_confirmed:true});
  assert.equal(s.tracking(customer,b.id).position,null);fails(()=>s.updateTracking(tech,b.id,point(session.session_id)),404);
  session=s.startTracking(f.otherTech,b.id,{consent:true});const auth=s.newSession(f.otherTech);s.logout(auth.token);assert.equal(s.tracking(customer,b.id).state,'not_sharing');
  session=s.startTracking(f.otherTech,b.id,{consent:true});
  for(const status of ['on_the_way','arrived','charging'])s.progress(f.otherTech,b.id,{status,version:s.row(b.id).version});
  s.submitReading(f.otherTech,b.id,{version:s.row(b.id).version,kind:'session',units:'10',photo});
  assert.equal(s.tracking(customer,b.id).state,'ended');assert.equal(s.tracking(customer,b.id).position,null);
  fails(()=>s.startTracking(f.otherTech,b.id,{consent:true}),409);
  // An independently created booking exercises cancellation without rewinding a completed job.
  const c=s.createBooking(customer,{vehicle_id:s.evs(customer)[0].id,address:'Second synthetic GPS test address',pincode:'600020',estimated_kwh:'10',slot:new Date(Date.now()+5*86400000).toISOString(),request_key:'gps-cancel-booking'});
  s.assign(admin,c.id,{version:c.version,technician_id:tech.id,fleet_id:'vehicle-1',slot:c.slot,compatibility_confirmed:true});s.startTracking(tech,c.id,{consent:true});s.cancel(customer,c.id,{version:s.row(c.id).version});assert.equal(s.tracking(customer,c.id).state,'ended');
});
test('sample GPS is explicitly enabled and labelled through HTTP',async t=>{
  const app=await createApplication({photo});const f=assigned(app.store);
  await new Promise(resolve=>app.server.listen(0,'127.0.0.1',resolve));t.after(()=>{app.server.close();app.store.close();});
  const base=`http://127.0.0.1:${app.server.address().port}/api/bookings/${f.booking.id}/tracking`;
  const tech=app.store.newSession(f.tech),customer=app.store.newSession(f.customer),other=app.store.newSession(f.other);
  const req=async(s,path='',data)=>{const r=await fetch(base+path,{method:data?'POST':'GET',headers:{Authorization:`Bearer ${s.token}`,'Content-Type':'application/json'},body:data?JSON.stringify(data):undefined});return {status:r.status,data:await r.json()};};
  assert.equal((await fetch(base)).status,401);
  const started=await req(tech,'/start',{consent:true,source:'sample'});assert.equal(started.status,200);assert.equal(started.data.tracking.source,'sample');
  assert.equal((await req(customer)).data.position.latitude,13.0188);assert.equal((await req(other)).status,404);
  assert.equal((await req(customer,'',point(started.data.session_id))).status,403);
  assert.equal((await req(tech,'/stop',{session_id:started.data.session_id})).data.position,null);
  const standard=new Store();standard.seed(photo);t.after(()=>standard.close());const f2=assigned(standard);fails(()=>standard.startTracking(f2.tech,f2.booking.id,{consent:true,source:'sample'}),403);
});
