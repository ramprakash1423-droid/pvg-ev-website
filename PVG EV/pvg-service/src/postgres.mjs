import pg from 'pg';
import {AsyncLocalStorage} from 'node:async_hooks';
import {EventEmitter} from 'node:events';
import {readFileSync} from 'node:fs';

pg.types.setTypeParser(20,value=>{const n=Number(value);if(!Number.isSafeInteger(n))throw new Error('Database integer exceeds supported range');return n;});
const columns={places:'id,customer_id,data',payment_orders:'id,invoice_id,status,amount,data'};
export class PostgresDatabase extends EventEmitter {
  constructor(connectionString){
    super();
    const u=new URL(connectionString);
    if(!u.hostname.endsWith('.supabase.com')&&!u.hostname.endsWith('.supabase.co'))throw new Error('Use the configured Supabase database');
    this.options={connectionString,ssl:{rejectUnauthorized:true,ca:readFileSync(new URL('../certs/supabase-ca.crt',import.meta.url),'utf8')},application_name:'pvg-customer-service',connectionTimeoutMillis:12000,statement_timeout:15000,options:'-c search_path=pvg_app,pg_catalog'};
    this.pool=new pg.Pool({...this.options,max:5});this.context=new AsyncLocalStorage();this.closed=false;
    this.pool.on('error',()=>this.emit('unavailable'));
  }
  prepare(source){
    let n=0;
    let sql=source.replace(/\?/g,()=>`$${++n}`).replace(/\browid\b/g,'created_order');
    sql=sql.replace(/INSERT INTO (places|payment_orders) VALUES/gi,(_,table)=>`INSERT INTO ${table} (${columns[table]}) VALUES`);
    const query=async values=>{const client=this.context.getStore()||this.pool;return client.query(sql,values);};
    return {get:async(...values)=>(await query(values)).rows[0],all:async(...values)=>(await query(values)).rows,run:async(...values)=>({changes:(await query(values)).rowCount})};
  }
  async tx(fn){
    if(this.context.getStore())return fn();
    const client=await this.pool.connect();
    try{
      await client.query('BEGIN');
      // Three-vehicle service: serialize transactional transitions to preserve assignment,
      // evidence, acceptance and payment invariants across multiple API requests.
      await client.query('SELECT pg_advisory_xact_lock(741901110)');
      const result=await this.context.run(client,fn);
      await client.query('COMMIT');return result;
    }catch(error){await client.query('ROLLBACK').catch(()=>{});throw error;}finally{client.release();}
  }
  async listen(){
    if(this.closed)return;
    const client=new pg.Client(this.options);this.listener=client;
    const disconnected=()=>{
      if(this.listener!==client)return;
      this.listener=null;this.emit('unavailable');void client.end().catch(()=>{});
      if(!this.closed)this.retry=setTimeout(()=>void this.listen(),3000);
    };
    client.on('error',disconnected);client.on('end',disconnected);
    client.on('notification',message=>{if(message.channel==='pvg_app_changes'){try{this.emit('change',JSON.parse(message.payload));}catch{}}});
    try{await client.connect();await client.query('LISTEN pvg_app_changes');this.emit('ready');}catch{disconnected();}
  }
  async close(){this.closed=true;clearTimeout(this.retry);const client=this.listener;this.listener=null;if(client)await client.end().catch(()=>{});await this.pool.end();}
}
