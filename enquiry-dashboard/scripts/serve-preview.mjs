import http from 'node:http';
import {readFile} from 'node:fs/promises';
import {resolve,extname,sep} from 'node:path';
import {createPreviewDashboard,previewAllowed} from './dashboard-preview.mjs';
const root=resolve(import.meta.dirname,'../dist');
const port=Number(process.env.PVG_DASHBOARD_PREVIEW_PORT||8101);
// Optional local form receipts; never read the live enquiry database in preview mode.
const receiptPath=process.env.PVG_PREVIEW_RECEIPTS;
const receiptText=receiptPath?await readFile(resolve(receiptPath),'utf8'):'';
const records=receiptText.split('\n').filter(Boolean).map(line=>JSON.parse(line));
const dashboard=await createPreviewDashboard({file:resolve(import.meta.dirname,'../.preview/dashboard-status.json'),localRecords:()=>records});
const config=JSON.parse(await readFile(resolve(root,'vercel.json'),'utf8'));
const headers=Object.fromEntries(config.headers[0].headers.map(({key,value})=>[key,value]));
const mime={'.html':'text/html; charset=utf-8','.css':'text/css','.js':'text/javascript','.png':'image/png','.webp':'image/webp','.txt':'text/plain'};
const server=http.createServer(async(req,res)=>{
 try{
  const url=new URL(req.url,'http://127.0.0.1');
  if(url.pathname==='/__preview/dashboard'){
   if(!previewAllowed(req,port)){res.writeHead(403,headers).end();return;}
   await dashboard(req,res,url);return;
  }
  if(!['GET','HEAD'].includes(req.method)){res.writeHead(405,{...headers,Allow:'GET, HEAD'}).end();return;}
  if(url.pathname==='/dashboard.html'){res.writeHead(302,{...headers,Location:'/'+url.search}).end();return;}
  const path=resolve(root,'.'+decodeURIComponent(url.pathname==='/'?'/index.html':url.pathname));
  if(!path.startsWith(root+sep)){res.writeHead(403,headers).end();return;}
  try{const content=await readFile(path);res.writeHead(200,{...headers,'Content-Type':mime[extname(path)]||'application/octet-stream'}).end(req.method==='HEAD'?undefined:content);}
  catch{res.writeHead(404,headers).end('Not found');}
 }catch{res.writeHead(400,headers).end('Invalid request');}
});
server.listen(port,'127.0.0.1',()=>console.log(`PVG dashboard preview: http://127.0.0.1:${port}/?preview=1 — sample data only.`));
