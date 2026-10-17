const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const contract=require('./fixtures/original-form-contract.json');
const decode=s=>s.replace(/&amp;/g,'&').replace(/&quot;/g,'"').replace(/&#x27;|&#39;/g,"'").replace(/&lt;/g,'<').replace(/&gt;/g,'>');
for(const [page,fields] of Object.entries(contract))test(`${page} preserves every original field, required rule and option`,()=>{
 const html=fs.readFileSync(path.join(__dirname,'..',page),'utf8');
 assert.match(html,/class="enquiry-form pvg-wizard"/);
 assert.match(html,/src="form-schema\.js/);assert.match(html,/src="form-wizard\.js/);
 for(const [name,expected] of Object.entries(fields)){
  const pattern=new RegExp('<(input|select|textarea)\\b[^>]*\\bname="'+name+'"[^>]*>');
  const m=html.match(pattern);assert.ok(m,`missing ${name}`);
  if(expected.required)assert.match(m[0],/\brequired\b/,`${name} must remain required`);
  assert.equal(m[0].match(/\btype="([^"]+)"/)?.[1]||m[1],expected.type,`${name} input type`);
  if(expected.options.length){
   const after=html.slice(m.index+m[0].length);const body=after.slice(0,after.indexOf('</select>'));
   const values=[...body.matchAll(/<option value="([^"]*)">/g)].map(match=>decode(match[1]));assert.deepEqual(values,expected.options,`${name} options`);
  }
 }
});
