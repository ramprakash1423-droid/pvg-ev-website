import http from 'node:http';
import {readFile,mkdir,appendFile} from 'node:fs/promises';
import {resolve,extname,sep} from 'node:path';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const {validate}=require('../form-core.js');
const root=resolve(import.meta.dirname,'../dist');
const log=resolve(import.meta.dirname,'../.preview/enquiries.jsonl');
const port=Number(process.env.PVG_PREVIEW_PORT||8100);
const seen=new Map();let nextReference=1001,saveQueue=Promise.resolve();
const history=await readFile(log,'utf8').catch(error=>{if(error.code==='ENOENT')return '';throw error;});
for(const line of history.split('\n').filter(Boolean)){
 const record=JSON.parse(line);
 if(record.id&&/^PVG-[1-9]\d{3,}$/.test(record.reference)){seen.set(record.id,record);nextReference=Math.max(nextReference,Number(record.reference.slice(4))+1);}
}
const mime={'.html':'text/html; charset=utf-8','.css':'text/css','.js':'text/javascript','.svg':'image/svg+xml','.jpg':'image/jpeg','.png':'image/png','.webp':'image/webp','.xml':'application/xml','.txt':'text/plain','.pdf':'application/pdf'};
const server=http.createServer(async(req,res)=>{
 try{
  const url=new URL(req.url,'http://127.0.0.1');
  if(url.pathname==='/__preview/enquiries'){
   if(req.method!=='POST'){res.writeHead(405,{Allow:'POST'}).end();return;}
   const origin=req.headers.origin;
   if(!origin||![`http://localhost:${port}`,`http://127.0.0.1:${port}`].includes(origin)){res.writeHead(403).end();return;}
   let body='';for await(const chunk of req){body+=chunk;if(body.length>32000){res.writeHead(413).end();return;}}
   const {p_submission_id:id,p_enquiry:record}=JSON.parse(body);
   if(!/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(id||'')||!record||!['request','contact','fleet','pilot'].includes(record.form_type)||validate(record.payload,record.form_type)){res.writeHead(400).end();return;}
   const saved=await(saveQueue=saveQueue.catch(()=>{}).then(async()=>{
    const existing=seen.get(id);
    if(existing){
     const {id:oldId,reference,saved_at,...original}=existing;
     const {reference:ignored,...incoming}=record;
     if(JSON.stringify(original)!==JSON.stringify(incoming))throw new Error('Submission ID already used');
     return existing;
    }
    const entry={...record,id,reference:`PVG-${nextReference++}`,saved_at:new Date().toISOString()};
    await mkdir(resolve(log,'..'),{recursive:true});await appendFile(log,JSON.stringify(entry)+'\n');seen.set(id,entry);return entry;
   }));
   res.writeHead(201,{'Content-Type':'application/json','Cache-Control':'no-store'}).end(JSON.stringify({saved:true,preview:true,reference:saved.reference}));return;
  }
  if(!['GET','HEAD'].includes(req.method)){res.writeHead(405).end();return;}
  const decoded=decodeURIComponent(url.pathname);
  const path=resolve(root,'.'+(decoded.endsWith('/')?decoded+'index.html':decoded));
  if(!path.startsWith(root+sep)){res.writeHead(403).end();return;}
  try{const content=await readFile(path);res.writeHead(200,{'Content-Type':mime[extname(path)]||'application/octet-stream','Cache-Control':'no-cache','X-Content-Type-Options':'nosniff'}).end(req.method==='HEAD'?undefined:content);}
  catch{res.writeHead(404,{'Content-Type':'text/html; charset=utf-8'}).end(await readFile(resolve(root,'404.html')));}
 }catch{res.writeHead(400).end('Invalid request');}
});
server.listen(port,'127.0.0.1',()=>console.log(`PVG-EV local preview running at http://127.0.0.1:${port} — test enquiries stay local.`));
