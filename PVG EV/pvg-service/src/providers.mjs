import {createHmac,timingSafeEqual} from 'node:crypto';
import {ApiError,ensure} from './domain.mjs';

export class RazorpayTest {
  constructor(env,fetcher=fetch){ensure(/^rzp_test_[A-Za-z0-9]+$/.test(env.RAZORPAY_KEY_ID||''),'Only Razorpay test keys are allowed in this pilot.',503);ensure(env.RAZORPAY_KEY_SECRET,'Razorpay test secret is missing.',503);this.key=env.RAZORPAY_KEY_ID;this.secret=env.RAZORPAY_KEY_SECRET;this.fetcher=fetcher;}
  async call(path,data){
    let response;try{response=await this.fetcher(`https://api.razorpay.com/v1${path}`,{method:data?'POST':'GET',headers:{Authorization:`Basic ${Buffer.from(this.key+':'+this.secret).toString('base64')}`,'Content-Type':'application/json'},...(data?{body:JSON.stringify(data)}:{}),signal:AbortSignal.timeout(20000)});}catch{throw new ApiError(502,'The payment provider did not respond. Check payment status before retrying.');}
    let result;try{result=await response.json();}catch{throw new ApiError(502,'Unexpected response from the payment provider.');}
    if(!response.ok){const error=new ApiError(502,response.status===401?'Razorpay authentication failed. Update the test API key pair.':'Razorpay rejected the test request. Check the test account configuration.');error.requestRejected=response.status>=400&&response.status<500;throw error;}return result;
  }
  async createOrder(local){const result=await this.call('/orders',{amount:local.amount,currency:'INR',receipt:local.id.replace('order_','').slice(0,40),notes:{source:'pvg_local_pilot',local_order:local.id}});ensure(/^order_[A-Za-z0-9]+$/.test(result.id)&&result.amount===local.amount&&result.currency==='INR','Unexpected payment order from provider.',502);return result;}
  signature(orderId,paymentId,signature){ensure(/^order_[A-Za-z0-9]+$/.test(orderId)&&/^pay_[A-Za-z0-9]+$/.test(paymentId),'Invalid payment identifiers.');ensure(/^[a-f0-9]{64}$/.test(signature||''),'Invalid payment signature.',401);const expected=createHmac('sha256',this.secret).update(`${orderId}|${paymentId}`).digest();ensure(timingSafeEqual(expected,Buffer.from(signature,'hex')),'Invalid payment signature.',401);}
  async verifiedPayment(order,paymentId){ensure(/^pay_[A-Za-z0-9]+$/.test(paymentId),'Invalid payment ID.');let payment=await this.call(`/payments/${paymentId}`);const data=JSON.parse(order.data);const matches=()=>payment.id===paymentId&&payment.order_id===data.provider_order_id&&payment.amount===order.amount&&payment.currency==='INR';ensure(matches(),'The payment does not match this invoice.',409);
    if(payment.status==='authorized'){payment=await this.call(`/payments/${paymentId}/capture`,{amount:order.amount,currency:'INR'});ensure(matches(),'Captured payment did not match this invoice.',409);}
    ensure(payment.status==='captured'&&payment.captured===true,'Payment is not captured yet. Check its status again shortly.',409);
    return {id:payment.id,type:'payment.captured',order_id:order.id,amount_paise:payment.amount,currency:payment.currency};
  }
  async reconcile(order){const data=JSON.parse(order.data);if(!data.provider_order_id)return null;const result=await this.call(`/orders/${data.provider_order_id}/payments`);const payment=(result.items||[]).find(p=>['captured','authorized'].includes(p.status));return payment?this.verifiedPayment(order,payment.id):null;}
}
export class TwoFactorSms {
  constructor(env,fetcher=fetch){ensure(env.TWOFACTOR_API_KEY,'2Factor SMS is not configured.',503);this.key=env.TWOFACTOR_API_KEY;this.sender=env.TWOFACTOR_SMS_SENDER_ID||'CLKACK';this.template=env.TWOFACTOR_SMS_TEMPLATE_NAME||'Clickacook_OTP';this.fetcher=fetcher;}
  async send(phone,code){ensure(/^[6-9]\d{9}$/.test(phone)&&!/^900000000[12]$/.test(phone),'Use your own valid mobile number for a real SMS.');let response;try{response=await this.fetcher(`https://2factor.in/API/V1/${encodeURIComponent(this.key)}/ADDON_SERVICES/SEND/TSMS`,{method:'POST',headers:{'Content-Type':'application/json',Accept:'application/json'},body:JSON.stringify({From:this.sender,To:`91${phone}`,TemplateName:this.template,VAR1:code}),signal:AbortSignal.timeout(15000)});}catch{throw new ApiError(502,'SMS provider did not respond. Wait a minute before requesting another code.');}
    let data;try{data=await response.json();}catch{throw new ApiError(502,'Unexpected response from the SMS provider.');}ensure(response.ok&&/^(success|accepted|queued)$/i.test(String(data.Status||data.status||'')),'SMS was not accepted. Check the sender/template setup.',502);return {accepted:true};
  }
}
