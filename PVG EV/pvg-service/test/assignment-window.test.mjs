import test from 'node:test';
import assert from 'node:assert/strict';
import {PostgresStore} from '../src/postgres-store.mjs';

// Isolated contract checks; no database connection or customer records are used.
function assignmentStore(minutes,otherMinutes=90){
  const date=new Date(Date.now()+86400000+330*60000).toISOString().slice(0,10);
  const at=Date.parse(`${date}T10:00:00+05:30`);
  let saved;
  const store=Object.create(PostgresStore.prototype);
  store.db={prepare(sql){
    if(sql.includes('FROM settings'))return {get:async()=>({data:JSON.stringify({open_minutes:360,close_minutes:1380,visit_minutes:minutes})})};
    if(sql.includes('FROM fleet'))return {get:async()=>({data:JSON.stringify({available:true,name:'Unit vehicle',registration:'UNIT ONLY'})})};
    if(sql.includes('FROM bookings'))return {all:async()=>[{data:JSON.stringify({slot:new Date(at+otherMinutes*60000).toISOString()})}]};
    throw new Error(`Unexpected query: ${sql}`);
  }};
  store.tx=fn=>fn();
  store.row=async()=>({id:'unit-booking',status:'requested',version:1});
  store.checkVersion=async()=>{};
  store.user=async()=>({role:'technician'});
  store.save=async(_,value)=>{saved=value;};
  store.audit=async()=>{};
  store.detail=async()=>saved;
  return {store,slot:new Date(at).toISOString()};
}
const admin={role:'admin'};
const input=slot=>({version:1,technician_id:'unit-tech',fleet_id:'unit-fleet',slot,compatibility_confirmed:true});
test('assignment accepts a non-overlapping configured one-hour window',async()=>{
  const {store,slot}=assignmentStore(60);
  assert.equal((await store.assign(admin,'unit-booking',input(slot))).status,'assigned');
});
test('assignment rejects overlap in a configured three-hour window',async()=>{
  const {store,slot}=assignmentStore(180,150);
  await assert.rejects(()=>store.assign(admin,'unit-booking',input(slot)),e=>e.status===409&&/configured service window/.test(e.message));
});
test('assignment requires a configured real planning window',async()=>{
  const {store,slot}=assignmentStore(null);
  await assert.rejects(()=>store.assign(admin,'unit-booking',input(slot)),e=>e.status===409&&/Set the travel/.test(e.message));
});
test('assignment leaves enough time before the configured closing hour',async()=>{
  const {store,slot}=assignmentStore(120,600);
  const date=slot.slice(0,10),late=`${date}T22:00:00+05:30`;
  await assert.rejects(()=>store.assign(admin,'unit-booking',input(late)),e=>e.status===409&&/before closing/.test(e.message));
});
