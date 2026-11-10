import test from 'node:test';
import assert from 'node:assert/strict';
import {canReceiveChange} from '../src/server.mjs';
test('live updates reach only the booking owner, assigned staff and admin',()=>{
  const change={kind:'booking_tracking',booking_id:'booking-a',users:['customer-a','tech-a']};
  for(const [role,id] of [['customer','customer-a'],['technician','tech-a'],['admin','admin-a']])assert.equal(canReceiveChange({role,id},change),true);
  for(const [role,id] of [['customer','customer-b'],['technician','tech-b']])assert.equal(canReceiveChange({role,id},change),false);
  assert.equal(canReceiveChange({role:'customer',id:'customer-a'},{kind:'bookings'}),false);
  assert.equal(canReceiveChange({role:'customer',id:'customer-a'},{kind:'settings'}),true);
});
