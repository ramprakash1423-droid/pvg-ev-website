// One explicitly enabled visit at a time. No GPS is requested during login or page load.
export class GpsSharing {
  constructor({api,geo,onChange,clock=()=>Date.now(),every=setInterval,cancel=clearInterval}) {
    Object.assign(this,{api,geo,onChange,clock,every,cancel});
    this.generation=0;this.bookingId=null;this.messageBookingId=null;this.sessionId=null;this.watchId=null;this.interval=null;this.message='';this.sending=false;this.lastSent=0;this.phase='idle';
  }
  changed(message){this.message=message;this.onChange(this);}
  async start(bookingId,{sample=false}={}) {
    await this.stop();
    this.messageBookingId=bookingId;
    if(!sample&&!this.geo){this.phase='error';this.changed('GPS is unavailable in this browser. Open the secure dashboard on your phone.');return;}
    const run=++this.generation;this.bookingId=bookingId;this.phase='starting';this.changed('Starting location sharing…');
    try {
      const result=await this.api(`/bookings/${bookingId}/tracking/start`,{consent:true,source:sample?'sample':'device'});
      if(run!==this.generation){await this.api(`/bookings/${bookingId}/tracking/stop`,{session_id:result.session_id}).catch(()=>{});return;}
      this.sessionId=result.session_id;this.sample=sample;this.phase='sharing';
      if(sample){this.changed('Sample GPS pin is visible to the sample customer. No device location is used.');return;}
      this.changed('Waiting for your phone’s GPS permission and a fresh location…');
      const received=position=>this.send(position,run);
      const failed=error=>{
        if(run!==this.generation)return;
        if(error.code===1){void this.stop('Location permission was denied. Allow location in your browser settings, then start sharing again.','error');return;}
        this.changed('GPS is temporarily unavailable. Keep this page open; another reading will be requested.');
      };
      const options={enableHighAccuracy:true,maximumAge:0,timeout:15000};
      this.watchId=this.geo.watchPosition(received,failed,options);
      // Ask for a fresh fix even while stationary; never resend an old coordinate as new.
      this.interval=this.every(()=>this.geo.getCurrentPosition(received,failed,options),15000);
    } catch(error) {if(run===this.generation)await this.stop(error.message,'error');}
  }
  async send(position,run) {
    if(run!==this.generation||!this.sessionId||this.sending)return;
    if(this.lastSent&&this.clock()-this.lastSent<10000)return;
    if(!Number.isFinite(position.timestamp)||this.clock()-position.timestamp>60000){this.changed('Waiting for a fresh GPS reading…');return;}
    if(!Number.isFinite(position.coords.accuracy)||position.coords.accuracy>500){this.changed('GPS accuracy is low. Move to an open area; the customer will see the last reliable update.');return;}
    this.sending=true;const bookingId=this.bookingId,sessionId=this.sessionId;
    try {
      await this.api(`/bookings/${bookingId}/tracking`,{session_id:sessionId,latitude:position.coords.latitude,longitude:position.coords.longitude,accuracy:position.coords.accuracy,captured_at:new Date(position.timestamp).toISOString()});
      if(run===this.generation){this.lastSent=this.clock();this.changed(`Sharing with this customer · last sent ${new Date(this.lastSent).toLocaleTimeString([], {hour:'2-digit',minute:'2-digit',second:'2-digit'})}`);}
    } catch(error) {
      if(run===this.generation){if([401,403,404,409].includes(error.status))await this.stop(error.message,'error');else this.changed('Could not send GPS. Check your connection; sharing will retry with a fresh reading.');}
    } finally {if(run===this.generation)this.sending=false;}
  }
  async stop(message='Location sharing stopped.',phase='stopped') {
    const bookingId=this.bookingId,sessionId=this.sessionId;
    this.generation++;
    if(this.watchId!==null)this.geo?.clearWatch(this.watchId);
    if(this.interval!==null)this.cancel(this.interval);
    if(bookingId)this.messageBookingId=bookingId;
    this.bookingId=null;this.sessionId=null;this.watchId=null;this.interval=null;this.sending=false;this.lastSent=0;this.sample=false;this.phase=phase;this.changed(message);
    if(bookingId&&sessionId)await this.api(`/bookings/${bookingId}/tracking/stop`,{session_id:sessionId},{keepalive:true}).catch(()=>{});
  }
}

// Small shared view model keeps retry/stop controls and errors consistent across refreshes.
export function gpsPanelState(booking,gps) {
  const tracking=booking.tracking||{},eligible=tracking.eligible===true;
  const active=eligible&&gps.bookingId===booking.id;
  const labels={live:'Location updated',stale:'Last location is outdated',waiting:'Waiting for a GPS reading',not_sharing:'Location sharing is off',awaiting_assignment:'Waiting for assignment',ended:'Tracking ended',expired:'Location sharing expired'};
  return {
    active,
    busy:active&&gps.phase==='starting',
    message:eligible&&gps.messageBookingId===booking.id&&gps.message?gps.message:labels[tracking.state]||'Location unavailable',
    recoverableError:eligible&&!active&&gps.messageBookingId===booking.id&&gps.phase==='error',
  };
}
