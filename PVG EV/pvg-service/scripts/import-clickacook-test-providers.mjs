// Copies only provider keys into an ignored local file. Does not modify Clickacook.
import {readFile,mkdir,writeFile,chmod} from 'node:fs/promises';
import {parseEnv} from 'node:util';
import {resolve} from 'node:path';
const source=process.argv[2];if(!source)throw new Error('Provide the local Clickacook backend .env path.');
const env=parseEnv(await readFile(source,'utf8'));
if(!env.RAZORPAY_KEY_ID?.startsWith('rzp_test_'))throw new Error('Refusing to copy a live payment key.');
const keys=['RAZORPAY_KEY_ID','RAZORPAY_KEY_SECRET','TWOFACTOR_API_KEY','TWOFACTOR_SMS_SENDER_ID','TWOFACTOR_SMS_TEMPLATE_NAME'];
const selected=Object.fromEntries(keys.filter(key=>env[key]).map(key=>[key,env[key]]));
const dir=resolve(import.meta.dirname,'../.local');await mkdir(dir,{recursive:true,mode:0o700});
const file=resolve(dir,'providers.json');await writeFile(file,JSON.stringify(selected),{mode:0o600});await chmod(file,0o600);
console.log('Imported Razorpay test and 2Factor settings into the ignored PVG local configuration. No credential values displayed.');
