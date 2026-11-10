import test from 'node:test';
import assert from 'node:assert/strict';
import {GpsSharing,gpsPanelState} from '../../enquiry-dashboard/tracking-client.js';
function fixture(){
  let success,error,interval,cleared=0,time=Date.now();const calls=[],messages=[];
  const geo={watchPosition(ok,fail){success=ok;error=fail;return 7;},clearWatch(){cleared++;},getCurrentPosition(ok){ok({timestamp:time,coords:{latitude:13,longitude:80,accuracy:15}});}};
  const api=async(path,data)=>{calls.push({path,data});return {session_id:'test-session'};};
  const gps=new GpsSharing({api,geo,onChange:g=>messages.push(g.message),clock:()=>time,every:fn=>{interval=fn;return 1;},cancel:()=>{interval=null;}});
  return {gps,calls,messages,advance:()=>time+=15000,point:()=>success({timestamp:time,coords:{latitude:13,longitude:80,accuracy:15}}),deny:()=>error({code:1}),tick:()=>interval?.(),cleared:()=>cleared};
}
test('technician GPS asks only after start, sends fresh fixes and ignores late callbacks after stop',async()=>{
  const f=fixture();assert.equal(f.calls.length,0);await f.gps.start('booking-one');await f.point();assert.equal(f.calls.at(-1).path,'/bookings/booking-one/tracking');
  f.advance();f.tick();await new Promise(r=>setImmediate(r));assert.equal(f.calls.filter(c=>c.path.endsWith('/tracking')).length,2);
  await f.gps.stop();const count=f.calls.length;f.advance();await f.point();assert.equal(f.calls.length,count);assert.equal(f.cleared(),1);assert.equal(f.gps.bookingId,null);
});
test('permission denial releases sharing and gives a recoverable message',async()=>{
  const f=fixture();await f.gps.start('booking-one');f.deny();await new Promise(r=>setImmediate(r));assert.equal(f.gps.bookingId,null);assert.match(f.gps.message,/permission was denied/);assert.ok(f.calls.some(c=>c.path.endsWith('/stop')));
});
test('sample GPS never calls device geolocation',async()=>{
  const f=fixture();await f.gps.start('booking-one',{sample:true});assert.equal(f.gps.watchId,null);assert.equal(f.calls.at(-1).data.source,'sample');assert.match(f.gps.message,/Sample GPS/);await f.gps.stop();
});

const booking={id:'booking-one',tracking:{eligible:true,state:'not_sharing'}};
test('denied permission stays visible after a panel refresh and can be retried',async()=>{
  const f=fixture();await f.gps.start(booking.id);f.deny();await new Promise(r=>setImmediate(r));
  const failed=gpsPanelState(booking,f.gps);assert.equal(failed.active,false);assert.equal(failed.busy,false);assert.equal(failed.recoverableError,true);assert.match(failed.message,/permission was denied/);
  assert.equal(gpsPanelState({...booking,id:'another-booking'},f.gps).recoverableError,false);
  await f.gps.start(booking.id);assert.equal(gpsPanelState(booking,f.gps).active,true);await f.point();assert.match(gpsPanelState(booking,f.gps).message,/last sent/);await f.gps.stop();
});
test('a failed sharing start restores retry controls rather than remaining busy',async()=>{
  const f=fixture();const api=f.gps.api;f.gps.api=async()=>{throw new Error('Connection unavailable. Try again.');};
  await f.gps.start(booking.id);const view=gpsPanelState(booking,f.gps);assert.equal(view.active,false);assert.equal(view.busy,false);assert.equal(view.recoverableError,true);assert.match(view.message,/Connection unavailable/);
  f.gps.api=api;await f.gps.start(booking.id);assert.equal(gpsPanelState(booking,f.gps).active,true);await f.gps.stop();
});
test('temporary upload failure retries with a fresh GPS fix and ending the visit removes controls',async()=>{
  const f=fixture(),api=f.gps.api;let fail=true;
  f.gps.api=async(path,data)=>{if(path.endsWith('/tracking')&&fail)throw new Error('Offline');return api(path,data);};
  await f.gps.start(booking.id);await f.point();assert.match(gpsPanelState(booking,f.gps).message,/connection/);assert.equal(f.gps.bookingId,booking.id);
  fail=false;f.advance();await f.point();assert.match(gpsPanelState(booking,f.gps).message,/last sent/);
  const ended=gpsPanelState({...booking,tracking:{eligible:false,state:'ended'}},f.gps);assert.equal(ended.active,false);assert.equal(ended.message,'Tracking ended');await f.gps.stop();
});
