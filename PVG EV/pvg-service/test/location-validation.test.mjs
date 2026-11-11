import test from 'node:test';
import assert from 'node:assert/strict';
import {isChennaiPin,validateChargingPin} from '../src/location-validation.mjs';
import {CustomerExperience} from '../src/customer-experience.mjs';
import {ensure} from '../src/domain.mjs';

test('Chennai-address pins reject remote/default simulator positions and allow address-only bookings',()=>{
  assert.equal(isChennaiPin(13.0827,80.2707),true);
  assert.equal(isChennaiPin(37.3349,-122.009),false);
  for(const pin of [[NaN,80],[13,Infinity],['13',80],[91,80]])assert.throws(()=>validateChargingPin(...pin));
  assert.throws(()=>validateChargingPin(37.3349,-122.009),/far outside Chennai/);
  assert.doesNotThrow(()=>validateChargingPin(null,null));
  assert.throws(()=>validateChargingPin(null,80));
});
function experience(status='requested'){
  const row={status,customer_id:'owner',version:2};let changes,audit;
  const store={db:{},tx:fn=>fn(),role:(u,r)=>ensure(u.role===r,'Role required',403),row:async()=>row,
    canRead:async(u,r)=>ensure(u.id===r.customer_id,'Not found',404),checkVersion:async(r,i)=>ensure(r.version===i.version,'Stale',409),
    save:async(_,value)=>{changes=value;},audit:async(_,u,action,data)=>{audit={action,data};},detail:async()=>({changes})};
  return {api:new CustomerExperience(store),getAudit:()=>audit};
}
const customer={id:'owner',role:'customer'};
test('an owner can remove an incorrect pin before departure without changing address or assignment',async()=>{
  const {api,getAudit}=experience('assigned');
  const result=await api.location(customer,'unit-visit',{version:2,latitude:null,longitude:null});
  assert.deepEqual(result.changes,{latitude:null,longitude:null});
  assert.equal(getAudit().action,'location_updated');
  assert.equal(JSON.stringify(getAudit()).includes('latitude'),false);
});
test('parking-pin changes enforce owner, version, explicit fields and departure boundary',async()=>{
  const {api}=experience();
  await assert.rejects(()=>api.location({...customer,id:'other'},'unit-visit',{version:2,latitude:null,longitude:null}),e=>e.status===404);
  await assert.rejects(()=>api.location(customer,'unit-visit',{version:1,latitude:null,longitude:null}),e=>e.status===409);
  await assert.rejects(()=>api.location(customer,'unit-visit',{version:2}),e=>e.status===400);
  await assert.rejects(()=>experience('on_the_way').api.location(customer,'unit-visit',{version:2,latitude:null,longitude:null}),e=>e.status===409);
});
