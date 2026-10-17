const {test}=require('node:test');
const assert=require('node:assert/strict');
const {create}=require('../form-location.js');
function fixture(){const calls=[],states=[];const gps={getCurrentPosition:(ok,error,options)=>calls.push({ok,error,options})};return {calls,states,control:create(gps,s=>states.push(s))};}
test('enter starts one automatic capture, without repeating on back/forward or during a request',()=>{
 const {calls,states,control}=fixture();control.enter();control.enter();control.retry();
 assert.equal(calls.length,1);assert.equal(states.at(-1).state,'locating');assert.equal(calls[0].options.enableHighAccuracy,true);assert.equal(calls[0].options.maximumAge,0);
 calls[0].ok({coords:{latitude:13.1,longitude:80.2,accuracy:9.8}});control.enter();
 assert.equal(calls.length,1);assert.deepEqual(states.at(-1),{state:'captured',latitude:13.1,longitude:80.2,accuracy:10});
});
test('permission denial does not loop; explicit retry can capture after permission is enabled',()=>{
 const {calls,states,control}=fixture();control.enter();calls[0].error({code:1});control.enter();assert.equal(calls.length,1);assert.equal(states.at(-1).state,'blocked');
 control.retry();calls[1].ok({coords:{latitude:0,longitude:0,accuracy:0}});assert.equal(states.at(-1).state,'captured');
});
test('clearing ignores a late GPS result and does not re-prompt automatically',()=>{
 const {calls,states,control}=fixture();control.enter();control.reset(false);calls[0].ok({coords:{latitude:13,longitude:80,accuracy:5}});control.enter();
 assert.equal(states.at(-1).state,'idle');assert.equal(calls.length,1);
 control.retry();assert.equal(calls.length,2);control.reset();control.enter();assert.equal(calls.length,3);
});
test('timeouts, invalid coordinates, unavailable APIs and synchronous failures have recoverable states',()=>{
 const {calls,states,control}=fixture();control.enter();calls[0].error({code:3});assert.equal(states.at(-1).reason,'timeout');
 control.retry();calls[1].ok({coords:{latitude:999,longitude:80}});assert.equal(states.at(-1).reason,'invalid');
 const absent=[];create(null,s=>absent.push(s)).enter();assert.equal(absent.at(-1).state,'unsupported');
 const errors=[];create({getCurrentPosition(){throw new Error('unavailable')}},s=>errors.push(s)).enter();assert.equal(errors.at(-1).state,'error');
});
