/* PVG-only username authentication. Passwords and session tokens are never persisted. */
((root,factory)=>{
  if(typeof module==='object'&&module.exports)module.exports=factory();
  else root.PVGDashboardAuth=factory();
})(typeof window!=='undefined'?window:this,()=>{
  'use strict';
  const dashboardUrl='https://pvg-ev-dashboard.vercel.app/';
  function create({url,key,fetch}){
    const headers={apikey:key,'Content-Type':'application/json'};
    async function login(username,password){
      const response=await fetch(`${url}/rest/v1/rpc/pvg_dashboard_login`,{method:'POST',headers,body:JSON.stringify({p_username:username,p_password:password}),cache:'no-store',signal:AbortSignal.timeout(12000)});
      if(response.status===429)throw new Error('Too many sign-in attempts. Please wait 15 minutes and try again.');
      if(!response.ok)throw new Error('Unable to connect to the dashboard. Please try again.');
      const data=await response.json();
      if(!data.ok){
        if(data.error==='rate_limited')throw new Error(`Too many sign-in attempts. Please try again in ${Math.max(1,Math.ceil((Number(data.retry_after)||900)/60))} minutes.`);
        if(data.error==='unavailable')throw new Error('Dashboard sign-in is not available yet. Please try again shortly.');
        throw new Error('Incorrect username or password. Please try again.');
      }
      if(typeof data.session_token!=='string'||!/^[0-9a-f]{64}$/.test(data.session_token)||!Number.isInteger(data.expires_in)||data.expires_in<=0||data.expires_in>3600)throw new Error('Unable to verify the dashboard session. Please sign in again.');
      return {session_token:data.session_token,expires_in:data.expires_in};
    }
    async function revoke(token){if(token)await fetch(`${url}/rest/v1/rpc/pvg_dashboard_logout`,{method:'POST',headers,body:JSON.stringify({p_session_token:token}),cache:'no-store',signal:AbortSignal.timeout(10000)});}
    return {login,revoke};
  }
  return {create,dashboardUrl};
});
