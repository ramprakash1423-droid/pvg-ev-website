const {test}=require('node:test');
const assert=require('node:assert/strict');
const {send}=require('../form-submit.js');
const {message}=require('../form-core.js');
const config={url:'https://example.supabase.co/',key:'public-test-key'};
const submissionId='8e713bda-ad16-4ba6-901e-365120961555';
const record={form_type:'contact',phone:'9999999999',payload:{consent:true}};
test('live submissions ask the server for the saved short reference',async()=>{
 let request;
 const reference=await send(record,submissionId,{config,fetcher:async(url,options)=>{request={url,...options};return {ok:true,json:async()=>({reference:'PVG-1001'})};}});
 assert.equal(reference,'PVG-1001');
 assert.equal(request.url,'https://example.supabase.co/rest/v1/rpc/submit_pvg_ev_enquiry');
 assert.deepEqual(JSON.parse(request.body),{p_submission_id:submissionId,p_enquiry:record});
 assert.equal(request.headers.Authorization,'Bearer public-test-key');
});
test('retries send the same private submission ID and receive the same reference',async()=>{
 const requests=[];
 const fetcher=async(url,options)=>{requests.push(options.body);if(requests.length===1)throw new Error('Response lost after save');return {ok:true,json:async()=>({reference:'PVG-1002'})};};
 await assert.rejects(send(record,submissionId,{config,fetcher}));
 assert.equal(await send(record,submissionId,{config,fetcher}),'PVG-1002');
 assert.equal(requests[0],requests[1]);
});
test('a rejected or malformed response never counts as a saved enquiry',async()=>{
 for(const response of [{ok:false,status:409},{ok:false,status:400},{ok:true,json:async()=>({})},{ok:true,json:async()=>({reference:'PVG-1792207655390-E053A9BF'})}]){
  await assert.rejects(send(record,submissionId,{config,fetcher:async()=>response}));
 }
});
test('local submissions use the local receipt server without Supabase credentials',async()=>{
 await send(record,submissionId,{local:true,fetcher:async(url,options)=>{
  assert.equal(url,'/__preview/enquiries');assert.deepEqual(options.headers,{'Content-Type':'application/json'});
  return {ok:true,json:async()=>({reference:'PVG-1003'})};
 }});
});
test('WhatsApp uses the saved reference and never shows an unassigned value',()=>{
 assert.match(message({name:'Test'},'contact','PVG-1004'),/Reference: PVG-1004/);
 assert.doesNotMatch(message({name:'Test'},'contact',null),/Reference:|null|undefined/);
});
