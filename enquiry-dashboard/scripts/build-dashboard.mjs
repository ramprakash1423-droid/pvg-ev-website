// Publish only dashboard assets, never SQL, credentials, tests or local receipts.
import {readFile,writeFile,mkdir,copyFile,rm} from 'node:fs/promises';
import {resolve,dirname} from 'node:path';
const root=resolve(import.meta.dirname,'..'),out=resolve(root,'dist');
const files=['index.html','dashboard.css','dashboard.js','dashboard-core.js','dashboard-auth.js','dashboard-config.js','site-config.js','form-schema.js','robots.txt','public/assets/pvg-ev/branding/pvg-ev-logo.webp','public/assets/pvg-ev/branding/favicon-pvg-ev.png'];
await rm(out,{recursive:true,force:true});await mkdir(out,{recursive:true});
for(const file of files){await mkdir(dirname(resolve(out,file)),{recursive:true});await copyFile(resolve(root,file),resolve(out,file));}
const config=JSON.parse(await readFile(resolve(root,'vercel.json'),'utf8'));
await writeFile(resolve(out,'vercel.json'),JSON.stringify({...config,buildCommand:null,outputDirectory:'.'},null,2)+'\n');
console.log(`Built ${files.length+1} dashboard-only files in dist/.`);
