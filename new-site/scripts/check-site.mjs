import {readdir,readFile,stat} from 'node:fs/promises';
import {resolve,dirname} from 'node:path';
const root=resolve(import.meta.dirname,'..');
const dirs=['','insights','guides'];
const files=(await Promise.all(dirs.map(async dir=>(await readdir(resolve(root,dir))).filter(f=>f.endsWith('.html')).map(f=>[dir,f].filter(Boolean).join('/'))))).flat();
const errors=[];
for(const file of files){
 const source=await readFile(resolve(root,file),'utf8');
 if((source.match(/<h1\b/g)||[]).length!==1)errors.push(`${file}: expected one h1`);
 const ids=[...source.matchAll(/\bid="([^"]+)"/g)].map(m=>m[1]);
 if(ids.length!==new Set(ids).size)errors.push(`${file}: duplicate ids`);
 for(const m of source.matchAll(/<(?:a|img|script|link)\b[^>]*?(?:href|src)="([^"]+)"/g)){
  const url=m[1];if(/^(https?:|tel:|mailto:|data:)/.test(url))continue;
  const [path,hash]=url.split('#');const clean=decodeURIComponent(path.split('?')[0]);
  const target=clean?resolve(clean.startsWith('/')?root:dirname(resolve(root,file)),'.'+(clean.startsWith('/')?'':'/')+clean):resolve(root,file);
  try{await stat(target);if(hash&&target.endsWith('.html')){const targetHtml=await readFile(target,'utf8');if(!targetHtml.includes(`id="${hash}"`))errors.push(`${file}: missing anchor ${url}`);}}catch{errors.push(`${file}: missing ${url}`);}
 }
 for(const m of source.matchAll(/<img\b[^>]*>/g)){if(!/alt="/.test(m[0])||!/width="/.test(m[0])||!/height="/.test(m[0]))errors.push(`${file}: image missing accessible text or dimensions`);}
}
if(errors.length){console.error(errors.join('\n'));process.exitCode=1;}else console.log(`Checked ${files.length} pages: links, anchors, image attributes and document structure pass.`);
