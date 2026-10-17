import http from 'node:http';
import {readFile,mkdir,appendFile} from 'node:fs/promises';
import {resolve,extname,sep} from 'node:path';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const {validate}=require('../form-core.js');
const root=resolve(import.meta.dirname,'../dist');
const log=resolve(import.meta.dirname,'../.preview/enquiries.jsonl');
const seen=new Set();
const mime={'.html':'text/html; charset=utf-8','.css':'text/css','.js':'text/javascript','.svg':'image/svg+xml','.jpg':'image/jpeg','.png':'image/png','.webp':'image/webp','.xml':'application/xml','.txt':'text/plain','.pdf':'application/pdf'};
const server=http.createServer(async(req,res)=>{
 try{
  const url=new URL(req.url,'http://127.0.0.1');
  if(url.pathname==='/__preview/enquiries'){
   if(req.method!=='POST'){res.writeHead(405,{Allow:'POST'}).end();return;}
   const origin=req.headers.origin;
   if(!origin||!/^http:\/\/(localhost|127\.0\.0\.1):8100$/.test(origin)){res.writeHead(403).end();return;}
   let body='';for await(const chunk of req){body+=chunk;if(body.length>32000){res.writeHead(413).end();return;}}
   const record=JSON.parse(body);
   if(!['request','contact','fleet','pilot'].includes(record.form_type)||!/^PVG-\d+-[A-Z0-9]{8}$/.test(record.reference)||validate(record.payload,record.form_type)){res.writeHead(400).end();return;}
   if(!seen.has(record.reference)){await mkdir(resolve(log,'..'),{recursive:true});await appendFile(log,JSON.stringify({...record,saved_at:new Date().toISOString()})+'\n');seen.add(record.reference);}
   res.writeHead(201,{'Content-Type':'application/json','Cache-Control':'no-store'}).end(JSON.stringify({saved:true,preview:true,reference:record.reference}));return;
  }
  if(!['GET','HEAD'].includes(req.method)){res.writeHead(405).end();return;}
  const decoded=decodeURIComponent(url.pathname);
  const path=resolve(root,'.'+(decoded.endsWith('/')?decoded+'index.html':decoded));
  if(!path.startsWith(root+sep)){res.writeHead(403).end();return;}
  try{const content=await readFile(path);res.writeHead(200,{'Content-Type':mime[extname(path)]||'application/octet-stream','Cache-Control':'no-cache','X-Content-Type-Options':'nosniff'}).end(req.method==='HEAD'?undefined:content);}
  catch{res.writeHead(404,{'Content-Type':'text/html; charset=utf-8'}).end(await readFile(resolve(root,'404.html')));}
 }catch{res.writeHead(400).end('Invalid request');}
});
server.listen(8100,'127.0.0.1',()=>console.log('PVG-EV local preview running at http://127.0.0.1:8100 — test enquiries stay local.'));
