// In-memory authenticated stream. Tokens never appear in URLs or local storage.
export class LiveUpdates {
  constructor({onEvent,onExpired}){this.onEvent=onEvent;this.onExpired=onExpired;this.generation=0;}
  stop(){this.generation++;this.controller?.abort();this.controller=null;clearTimeout(this.timer);}
  start(token){this.stop();void this.connect(token,this.generation);}
  async connect(token,generation){
    if(generation!==this.generation)return;
    const controller=new AbortController();this.controller=controller;
    let watchdog;
    const resetWatchdog=()=>{clearTimeout(watchdog);watchdog=setTimeout(()=>controller.abort(),45000);};
    try{
      resetWatchdog();
      const response=await fetch('/api/events',{headers:{Authorization:`Bearer ${token}`,Accept:'text/event-stream'},cache:'no-store',signal:controller.signal});
      if(response.status===401){this.onExpired();return;}
      if(!response.ok)throw Error('Live connection unavailable');
      const reader=response.body.getReader(),decoder=new TextDecoder();let buffer='';
      for(;;){const {value,done}=await reader.read();if(done)break;resetWatchdog();if(generation!==this.generation)return;buffer+=decoder.decode(value,{stream:true});let split;
        while((split=buffer.indexOf('\n\n'))>=0){const packet=buffer.slice(0,split);buffer=buffer.slice(split+2);if(!packet.startsWith('data: '))continue;const event=JSON.parse(packet.slice(6));if(event.kind==='session_expired'){this.onExpired();return;}this.onEvent(event);}
      }
    }catch{}finally{clearTimeout(watchdog);}
    if(generation!==this.generation)return;
    this.onEvent({kind:'connection_lost'});this.timer=setTimeout(()=>void this.connect(token,generation),3000);
  }
}
