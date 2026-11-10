const {test}=require('node:test');
const assert=require('node:assert/strict');
const A=require('../dashboard-auth.js');
const token='a'.repeat(64);
function fixture(data={ok:true,session_token:token,expires_in:3600},status=200){
 const calls=[];const auth=A.create({url:'https://project.supabase.co',key:'public-test-key',fetch:async(url,options)=>{calls.push({url,options});return {ok:status===200,status,json:async()=>data};}});return {auth,calls};
}
test('PVG username login sends credentials only to its server RPC and returns an opaque session',async()=>{
 const f=fixture();assert.deepEqual(await f.auth.login('admin','synthetic-test-password'),{session_token:token,expires_in:3600});
 assert.equal(f.calls[0].url,'https://project.supabase.co/rest/v1/rpc/pvg_dashboard_login');
 assert.deepEqual(JSON.parse(f.calls[0].options.body),{p_username:'admin',p_password:'synthetic-test-password'});
 assert.equal(f.calls[0].options.method,'POST');assert.equal(f.calls[0].options.cache,'no-store');
 assert.ok(!f.calls[0].url.includes('synthetic-test-password'));assert.ok(!f.calls[0].url.includes('/auth/'));
});
test('wrong credentials and persisted rate limits have clear recoverable errors',async()=>{
 await assert.rejects(fixture({ok:false,error:'invalid_login'}).auth.login('bad','bad'),/Incorrect username or password/);
 await assert.rejects(fixture({ok:false,error:'rate_limited',retry_after:900}).auth.login('bad','bad'),/15 minutes/);
 await assert.rejects(fixture({ok:false,error:'unavailable'}).auth.login('admin','test'),/not available/);
 for(const status of [401,429,500])await assert.rejects(fixture({},status).auth.login('admin','test'));
});
test('malformed sessions never count as a successful login',async()=>{
 for(const data of [{ok:true},{ok:true,session_token:'not-a-token',expires_in:3600},{ok:true,session_token:token,expires_in:0},{ok:true,session_token:token,expires_in:7200},{ok:true,session_token:token,expires_in:'3600'}])await assert.rejects(fixture(data).auth.login('admin','test'),/Unable to verify/);
});
test('logout revokes only the presented PVG session and never calls shared authentication APIs',async()=>{
 const f=fixture();await f.auth.revoke(token);assert.equal(f.calls[0].url,'https://project.supabase.co/rest/v1/rpc/pvg_dashboard_logout');assert.deepEqual(JSON.parse(f.calls[0].options.body),{p_session_token:token});
 await f.auth.revoke();assert.equal(f.calls.length,1);
});
