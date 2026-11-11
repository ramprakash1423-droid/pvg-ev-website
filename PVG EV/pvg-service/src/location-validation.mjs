import {ensure} from './domain.mjs';

// A broad sanity boundary for a Chennai-address pin, not a service-coverage claim.
export function isChennaiPin(latitude,longitude){
  if(!Number.isFinite(latitude)||!Number.isFinite(longitude)||Math.abs(latitude)>90||Math.abs(longitude)>180)return false;
  const rad=n=>n*Math.PI/180,lat=rad(latitude),base=rad(13.0827);
  const a=Math.sin((lat-base)/2)**2+Math.cos(base)*Math.cos(lat)*Math.sin(rad(longitude-80.2707)/2)**2;
  return 6371000*2*Math.atan2(Math.sqrt(a),Math.sqrt(Math.max(0,1-a)))<=150000;
}
export function validateChargingPin(latitude,longitude){
  if(latitude==null&&longitude==null)return;
  ensure(isChennaiPin(latitude,longitude),'That pin is far outside Chennai. Choose your parking spot on the map or continue with the address without a GPS pin.');
}
