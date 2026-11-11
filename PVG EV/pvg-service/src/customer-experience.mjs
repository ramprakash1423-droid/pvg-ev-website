import {ensure,id,now} from './domain.mjs';
import {validateChargingPin} from './location-validation.mjs';
const IST=330*60000;
const hourLabel=m=>`${(Math.floor(m/60)%12)||12}:${String(m%60).padStart(2,'0')} ${m<720?'AM':'PM'}`;
export function validateVisitTime(value, settings, clock=Date.now()) {
  const time=Date.parse(value), local=new Date(time+IST);
  ensure(Number.isFinite(time)&&time>clock&&time<clock+31*86400000,'Choose a future visit within 30 days.');
  if(settings){const minutes=local.getUTCHours()*60+local.getUTCMinutes();ensure(minutes>=settings.open_minutes&&minutes<settings.close_minutes,`Choose a time between ${hourLabel(settings.open_minutes)} and ${hourLabel(settings.close_minutes)} (India time).`);}
  return time;
}
export function availableSlots({date,settings,vehicles,technicians,bookings,clock=Date.now()}) {
  if(!settings||!Number.isInteger(settings.visit_minutes)||settings.visit_minutes<30||!vehicles.length||!technicians.length)return [];
  const start=Date.parse(`${date}T00:00:00+05:30`),duration=settings.visit_minutes*60000,result=[];
  for(let m=settings.open_minutes;m+settings.visit_minutes<=settings.close_minutes;m+=30){
    const at=start+m*60000;if(at<=clock)continue;
    const conflicts=bookings.filter(b=>!['cancelled','paid'].includes(b.status)&&Math.abs(Date.parse(b.slot)-at)<duration);
    const freeVehicle=vehicles.some(v=>!conflicts.some(b=>b.fleet_id===v.id));
    const freeTech=technicians.some(t=>!conflicts.some(b=>b.technician_id===t.id));
    if(freeVehicle&&freeTech)result.push(new Date(at).toISOString());
  }
  return result;
}
export class CustomerExperience {
  constructor(store){this.store=store;this.db=store.db;}
  async settings(){const row=await this.db.prepare("SELECT data FROM settings WHERE id='service'").get();return row?JSON.parse(row.data):null;}
  async saveSettings(user,input){
    this.store.role(user,'admin');
    const {open_minutes,close_minutes,visit_minutes}=input;
    ensure(Number.isInteger(open_minutes)&&Number.isInteger(close_minutes)&&open_minutes>=0&&close_minutes<=1440&&close_minutes>open_minutes,'Enter valid opening and closing hours.');
    ensure(Number.isInteger(visit_minutes)&&visit_minutes>=30&&visit_minutes<=240,'Allow 30–240 minutes per travel and charging visit.');
    ensure(Array.isArray(input.pincodes)&&input.pincodes.length<=200&&input.pincodes.every(p=>/^600\d{3}$/.test(p)),'Enter Chennai service pincodes.');
    const value={open_minutes,close_minutes,visit_minutes,pincodes:[...new Set(input.pincodes)],updated_at:now()};
    await this.db.prepare("INSERT INTO settings(id,data) VALUES('service',?) ON CONFLICT(id) DO UPDATE SET data=excluded.data").run(JSON.stringify(value));return value;
  }
  async availability(input){
    const settings=await this.settings(),pincode=input.pincode||'';
    ensure(!pincode||/^\d{6}$/.test(pincode),'Enter a six-digit pincode.');
    const date=input.date||new Date(Date.now()+IST).toISOString().slice(0,10);
    ensure(/^\d{4}-\d{2}-\d{2}$/.test(date)&&Number.isFinite(Date.parse(date+'T00:00:00+05:30')),'Choose a valid date.');
    const dateValue=Date.parse(date+'T00:00:00+05:30');
    ensure(dateValue>Date.now()-86400000&&dateValue<Date.now()+31*86400000,'Choose a date within 30 days.');
    const vehicles=(await this.db.prepare('SELECT data FROM fleet').all()).map(r=>JSON.parse(r.data)).filter(v=>v.available);
    const technicians=await this.db.prepare("SELECT id FROM users WHERE role='technician'").all();
    const rows=await this.db.prepare("SELECT technician_id,fleet_id,data FROM bookings WHERE status NOT IN ('cancelled','paid')").all();
    const bookings=rows.map(r=>({...JSON.parse(r.data),technician_id:r.technician_id,fleet_id:r.fleet_id}));
    const areaKnown=!!settings?.pincodes?.length;
    const covered=pincode&&areaKnown?settings.pincodes.includes(pincode):null;
    const outside=pincode&&!/^600\d{3}$/.test(pincode)||covered===false;
    const slots=!outside&&covered===true?availableSlots({date,settings,vehicles,technicians,bookings}):[];
    const state=outside?'outside_area':!settings||!settings.visit_minutes||!vehicles.length||!technicians.length?'confirmation_required':covered!==true?'check_address':slots.length?'slots_available':'no_slots';
    return {state,date,settings:settings?{open_minutes:settings.open_minutes,close_minutes:settings.close_minutes,visit_minutes:settings.visit_minutes}:null,slots,
      message:({outside_area:'This pincode is outside the current service area. Contact PVG for help.',confirmation_required:'Request your preferred time. PVG will confirm the charging team and availability.',check_address:'PVG will confirm coverage for your address before assigning a visit.',slots_available:'Available request times based on the current schedule. PVG confirms your vehicle and connector before assignment.',no_slots:'No available times on this date. Choose another day or contact PVG.'})[state]};
  }
  async reschedule(user,bookingId,input){
    return this.store.tx(async()=>{
      this.store.role(user,'customer');const row=await this.store.row(bookingId);await this.store.canRead(user,row);await this.store.checkVersion(row,input);
      ensure(['requested','assigned'].includes(row.status),'The vehicle has already departed. Contact support to change the visit.',409);
      validateVisitTime(input.slot,await this.settings());
      const old=JSON.parse(row.data);
      await this.store.save(row,{status:'requested',slot:new Date(input.slot).toISOString(),previous_slot:old.slot,technician_id:null,fleet_id:null,fleet_name:null,fleet_registration:null,compatibility_confirmed:false,service_note:null});
      await this.store.audit(bookingId,user,'rescheduled',{note:'New preferred time requested; assignment will be reconfirmed.'});return this.store.detail(user,bookingId);
    });
  }
  async location(user,bookingId,input){
    return this.store.tx(async()=>{
      this.store.role(user,'customer');const row=await this.store.row(bookingId);
      await this.store.canRead(user,row);await this.store.checkVersion(row,input);
      ensure(['requested','assigned'].includes(row.status),'The vehicle has already departed. Contact support to change the parking pin.',409);
      ensure(Object.hasOwn(input,'latitude')&&Object.hasOwn(input,'longitude'),'Choose or remove the parking pin explicitly.');
      validateChargingPin(input.latitude,input.longitude);
      await this.store.save(row,{latitude:input.latitude??null,longitude:input.longitude??null});
      await this.store.audit(bookingId,user,'location_updated',{note:input.latitude==null?'Customer removed the parking pin; use their address.':'Customer updated the parking pin.'});
      return this.store.detail(user,bookingId);
    });
  }
  async support(user,bookingId,input){
    return this.store.tx(async()=>{
      const row=await this.store.row(bookingId);await this.store.canRead(user,row);await this.store.checkVersion(row,input);const data=JSON.parse(row.data);
      ensure(typeof input.message==='string'&&input.message.trim().length>=5&&input.message.length<=1000,'Describe the issue in 5–1,000 characters.');
      if(user.role==='customer'){
        ensure(!data.support_request||data.support_request.status==='resolved','This visit already has an open support request.',409);
        ensure(['arrival','location','charging','payment','other'].includes(input.category),'Choose a support topic.');
        const ticket={id:id('support'),category:input.category,message:input.message.trim(),status:'open',created_at:now()};
        await this.store.save(row,{support_request:ticket});await this.store.audit(bookingId,user,'support_requested',{note:ticket.message});
      }else{
        this.store.role(user,'admin');ensure(data.support_request,'No support request exists.',409);
        ensure(['in_progress','resolved'].includes(input.status),'Choose a support status.');
        await this.store.save(row,{support_request:{...data.support_request,status:input.status,response:input.message.trim(),updated_at:now()}});await this.store.audit(bookingId,user,'support_updated',{note:input.message.trim()});
      }
      return this.store.detail(user,bookingId);
    });
  }
  async serviceUpdate(user,bookingId,input){
    return this.store.tx(async()=>{
      ensure(['admin','technician'].includes(user.role),'Staff access required.',403);
      const row=await this.store.row(bookingId);await this.store.canRead(user,row);await this.store.checkVersion(row,input);
      ensure(['assigned','on_the_way','arrived','charging'].includes(row.status),'This visit is not in progress.',409);
      ensure(typeof input.message==='string'&&input.message.trim().length>=5&&input.message.length<=500,'Enter an update for the customer.');
      if(input.failed){ensure(['assigned','on_the_way','arrived'].includes(row.status),'If charging has started, submit the delivered units and report the issue.',409);}
      await this.store.save(row,{service_note:{message:input.message.trim(),created_at:now()},...(input.failed?{status:'cancelled',failure_reason:input.message.trim()}:{})});
      await this.store.audit(bookingId,user,input.failed?'visit_unavailable':'service_update',{note:input.message.trim()});return this.store.detail(user,bookingId);
    });
  }
  async draft(user,input){
    this.store.role(user,'customer');
    if(input===undefined)return (await this.store.preferences(user)).booking_draft||{};
    ensure(JSON.stringify(input).length<6000,'Booking draft is too long.');
    for(const key of ['vehicle_id','address','pincode','access_notes','slot','request_key'])ensure(input[key]==null||typeof input[key]==='string','Invalid booking draft.');
    for(const key of ['latitude','longitude'])ensure(input[key]==null||typeof input[key]==='number'&&Number.isFinite(input[key])&&Math.abs(input[key])<=(key==='latitude'?90:180),'Invalid location.');
    return this.store.tx(async()=>{
      const prefs=await this.store.preferences(user);
      prefs.booking_draft=input.clear?null:{...Object.fromEntries(['vehicle_id','address','pincode','latitude','longitude','access_notes','slot','request_key'].filter(k=>input[k]!==undefined).map(k=>[k,input[k]])),updated_at:now()};
      await this.store.writePreferences(user,prefs);return {saved:true};
    });
  }
}
