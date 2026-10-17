/* Return the reference only after the server confirms the enquiry was saved. */
(function(root,factory){
  if(typeof module==='object'&&module.exports)module.exports=factory();
  else root.PVGSubmit=factory();
})(typeof globalThis!=='undefined'?globalThis:this,function(){
  'use strict';
  async function send(record,submissionId,{config,local=false,fetcher=globalThis.fetch}={}){
    const url=local?'/__preview/enquiries':`${config.url.replace(/\/$/,'')}/rest/v1/rpc/submit_pvg_ev_enquiry`;
    const headers=local?{'Content-Type':'application/json'}:{'Content-Type':'application/json',apikey:config.key,Authorization:`Bearer ${config.key}`};
    const response=await fetcher(url,{method:'POST',headers,body:JSON.stringify({p_submission_id:submissionId,p_enquiry:record}),signal:AbortSignal.timeout(10000)});
    if(!response.ok)throw new Error('Enquiry could not be confirmed.');
    const saved=await response.json();
    if(!/^PVG-[1-9]\d{3,}$/.test(saved?.reference||''))throw new Error('Enquiry reference was not confirmed.');
    return saved.reference;
  }
  return {send};
});
