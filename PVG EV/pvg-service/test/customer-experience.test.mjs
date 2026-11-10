import test from 'node:test';
import assert from 'node:assert/strict';
import {availableSlots,validateVisitTime} from '../src/customer-experience.mjs';
import {createApplication} from '../src/server.mjs';
const settings={open_minutes:360,close_minutes:1380,visit_minutes:120};
test('slots require real fleet and staff and exclude overlap and closing time',()=>{
 const input={date:'2030-01-02',settings,vehicles:[{id:'v'}],technicians:[{id:'t'}],bookings:[],clock:Date.parse('2030-01-01T00:00:00Z')};
 assert.equal(availableSlots({...input,vehicles:[]}).length,0);
 assert.equal(availableSlots({...input,settings:{...settings,visit_minutes:null}}).length,0);
 assert.equal(availableSlots({...input,technicians:[]}).length,0);
 const slots=availableSlots(input);assert.equal(slots[0],'2030-01-02T00:30:00.000Z');assert.equal(slots.at(-1),'2030-01-02T15:30:00.000Z');
 const at='2030-01-02T04:30:00.000Z';
 const booked=availableSlots({...input,bookings:[{status:'assigned',slot:at,fleet_id:'v',technician_id:'t'}]});assert.ok(!booked.includes(at));assert.ok(booked.includes('2030-01-02T06:30:00.000Z'));
});
test('visit hours are validated in IST, not server timezone',()=>{
 const clock=Date.parse('2030-01-01T00:00:00Z');
 assert.ok(validateVisitTime('2030-01-02T00:30:00Z',settings,clock));
 for(const t of ['2030-01-02T00:29:00Z','2030-01-02T17:30:00Z','invalid','2031-01-01T00:00:00Z'])assert.throws(()=>validateVisitTime(t,settings,clock));
});
test('browser login uses HttpOnly cookie, restores validated session and protects signout origin',async t=>{
 const app=await createApplication({seed:false});await new Promise(r=>app.server.listen(0,'127.0.0.1',r));
 t.after(async()=>{await new Promise(r=>app.server.close(r));app.store.close();});
 const base=`http://127.0.0.1:${app.server.address().port}`,origin='http://127.0.0.1:8202';
 const otp=app.store.requestOtp('9876543210','Isolated verification');
 let r=await fetch(base+'/api/auth/verify',{method:'POST',headers:{'Content-Type':'application/json',Origin:origin},body:JSON.stringify({challenge_id:otp.challenge_id,code:otp.preview_code,client:'web'})});
 assert.equal(r.status,200);assert.equal(r.headers.get('access-control-allow-credentials'),'true');
 const auth=await r.json();assert.equal(auth.token,undefined);
 const fullCookie=r.headers.get('set-cookie');assert.match(fullCookie,/HttpOnly/);assert.match(fullCookie,/SameSite=Strict/);
 const cookie=fullCookie.split(';')[0];
 r=await fetch(base+'/api/auth/session',{headers:{Cookie:cookie,Origin:origin}});assert.equal(r.status,200);assert.equal((await r.json()).user.role,'customer');
 r=await fetch(base+'/api/auth/logout',{method:'POST',headers:{Cookie:cookie,'Content-Type':'application/json'},body:'{}'});assert.equal(r.status,403);
 r=await fetch(base+'/api/auth/logout',{method:'POST',headers:{Cookie:cookie,Origin:origin,'Content-Type':'application/json'},body:'{}'});assert.equal(r.status,200);assert.match(r.headers.get('set-cookie'),/Max-Age=0/);
 r=await fetch(base+'/api/auth/session',{headers:{Cookie:cookie}});assert.equal(r.status,401);
});
