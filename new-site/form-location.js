/* One-shot GPS capture. Location is requested only on entering the location step or retrying. */
(function(root,factory){
  if(typeof module==='object'&&module.exports)module.exports=factory();
  else root.PVGLocation=factory();
})(typeof window==='undefined'?globalThis:window,function(){
  'use strict';
  function create(geolocation,onState){
    let attempted=false,pending=false,generation=0;
    function capture(){
      if(pending)return;
      attempted=true;
      if(!geolocation){onState({state:'unsupported'});return;}
      const current=++generation;pending=true;onState({state:'locating'});
      const finish=state=>{if(current!==generation)return;pending=false;onState(state);};
      try{
        geolocation.getCurrentPosition(position=>{
          const {latitude,longitude,accuracy}=position.coords||{};
          if(!Number.isFinite(latitude)||!Number.isFinite(longitude)||Math.abs(latitude)>90||Math.abs(longitude)>180){finish({state:'error',reason:'invalid'});return;}
          finish({state:'captured',latitude,longitude,accuracy:Number.isFinite(accuracy)&&accuracy>=0?Math.round(accuracy):null});
        },error=>finish({state:error.code===1?'blocked':'error',reason:error.code===3?'timeout':'unavailable'}),{enableHighAccuracy:true,timeout:15000,maximumAge:0});
      }catch{finish({state:'error',reason:'unavailable'});}
    }
    return {
      enter(){if(!attempted)capture();},
      retry:capture,
      reset(allowAutomatic=true){generation++;pending=false;attempted=!allowAutomatic;onState({state:'idle'});}
    };
  }
  return {create};
});
