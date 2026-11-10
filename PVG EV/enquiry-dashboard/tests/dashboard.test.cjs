const {test}=require('node:test');
const assert=require('node:assert/strict');
const {mkdtemp,rm}=require('node:fs/promises');
const {tmpdir}=require('node:os');
const {join}=require('node:path');
const {Readable}=require('node:stream');
const D=require('../dashboard-core.js');
const schema=require('../form-schema.js');

test('dashboard filters combine, counts remain global and pages are bounded',async()=>{
 const {samples}=await import('../scripts/dashboard-preview.mjs');const records=samples(new Date('2026-10-28T10:00:00Z'));
 const result=D.query(records,{search:'MEERA',type:'fleet',status:'new',limit:1});
 assert.equal(result.total,1);assert.equal(result.records[0].name,'Meera Iyer');assert.deepEqual(result.stats,{total:6,new:3,active:2,closed:1});
 assert.equal(D.query(records,{search:'MEERA',type:'contact'}).total,0);
 assert.equal(D.query(records,{status:'active'}).total,2);
 assert.equal(D.query(records,{limit:2,offset:2}).records[0].name,'Vikram Shah');
 assert.equal(D.query(records,{search:'%'}).total,0);
 assert.equal(D.query(records,{since:'2026-10-28T00:00:00Z'}).total,3);
});
test('Today starts at midnight in India regardless of the browser timezone',()=>{
 assert.equal(D.dateStart('today',new Date('2026-10-28T20:00:00Z')),'2026-10-28T18:30:00.000Z');
 assert.equal(D.dateStart('7',new Date('2026-10-28T10:00:00Z')),'2026-10-21T10:00:00.000Z');
 assert.equal(D.dateStart('all'),null);
});
test('map and phone links only use validated values, never applicant URLs',()=>{
 for(const record of [{latitude:'',longitude:''},{latitude:91,longitude:0},{latitude:null,longitude:null},{latitude:'javascript:alert(1)',longitude:1},{gps_location:'javascript:alert(1)'}])assert.equal(D.mapUrl(record),null);
 assert.equal(D.mapUrl({latitude:0,longitude:0}),'https://www.google.com/maps/search/?api=1&query=0,0');
 assert.equal(D.phoneDigits('+91 97510 83000'),'919751083000');assert.equal(D.phoneDigits('javascript:1'),null);
});
test('full details preserve arrays, consent and legacy columns without internal metadata',()=>{
 const fields=D.fields({id:'private-id',form_type:'request',payload:{name:'<script>alert(1)</script>',consent:true,pilot_interest:['Community','Fleet'],website:''},vehicle_model:'Legacy model',latitude:0},schema);
 assert.ok(fields.some(f=>f.label==='Name'&&f.value==='<script>alert(1)</script>'));
 assert.ok(fields.some(f=>f.value==='Community, Fleet'));assert.ok(fields.some(f=>f.value==='Legacy model'));assert.ok(fields.some(f=>f.value==='Yes'));
 assert.ok(!fields.some(f=>f.value==='private-id'||f.label==='Website'));
 const mapped=D.fields({form_type:'contact',payload:{requirement:'General Enquiry',telephone:'9000000000',contact_time:'Morning'},requirement_type:'General Enquiry',phone:'9000000000',preferred_time:'Morning'},schema);
 assert.equal(mapped.length,3);
});
test('local dashboard rejects foreign origins, DNS rebinding hosts and missing request marker',async()=>{
 const {previewAllowed}=await import('../scripts/dashboard-preview.mjs');const headers={host:'127.0.0.1:8100','x-pvg-preview':'dashboard',origin:'http://127.0.0.1:8100','sec-fetch-site':'same-origin'};
 assert.equal(previewAllowed({headers},8100),true);
 for(const changed of [{origin:'https://evil.example'},{host:'evil.example:8100'},{'sec-fetch-site':'cross-site'},{'x-pvg-preview':undefined}])assert.equal(previewAllowed({headers:{...headers,...changed}},8100),false);
});
async function invoke(handler,method,params,body){
 const req=Readable.from(body?[JSON.stringify(body)]:[]);req.method=method;
 const response={writeHead(status,headers){this.status=status;this.headers=headers;return this;},setHeader(){},end(data){this.data=JSON.parse(data);return this;}};
 await handler(req,response,new URL('http://127.0.0.1/__preview/dashboard?'+new URLSearchParams(params)));return response;
}
test('local status updates persist, reject stale writes and never alter form receipts',async()=>{
 const {createPreviewDashboard}=await import('../scripts/dashboard-preview.mjs');const dir=await mkdtemp(join(tmpdir(),'pvg-dashboard-'));
 try{
  const receipt={id:'test-local',name:'Local test',reference:'PVG-9000',form_type:'contact',status:'new',saved_at:'2026-10-28T10:00:00Z',payload:{name:'Local test'}};
  const before=JSON.stringify(receipt),options={file:join(dir,'status.json'),localRecords:()=>[receipt],now:new Date('2026-10-28T10:00:00Z')};
  const handler=await createPreviewDashboard(options),list=await invoke(handler,'GET',{source:'local'});
  assert.equal(list.status,200);assert.equal(list.headers['Cache-Control'],'no-store');assert.equal(list.data.records[0].created_at,receipt.saved_at);
  const update={source:'local',id:receipt.id,status:'contacted',expected_updated_at:receipt.saved_at};
  assert.equal((await invoke(handler,'PATCH',{},update)).status,200);
  assert.equal((await invoke(handler,'PATCH',{},update)).status,409);
  assert.equal((await invoke(handler,'PATCH',{},{...update,status:'deleted'})).status,400);
  assert.equal((await invoke(handler,'PATCH',{},{...update,id:'missing'})).status,404);
  assert.equal(JSON.stringify(receipt),before);
  const restarted=await createPreviewDashboard(options);assert.equal((await invoke(restarted,'GET',{source:'local'})).data.records[0].status,'contacted');
  assert.equal((await invoke(restarted,'GET',{source:'sample'})).data.total,6);
 }finally{await rm(dir,{recursive:true,force:true});}
});
