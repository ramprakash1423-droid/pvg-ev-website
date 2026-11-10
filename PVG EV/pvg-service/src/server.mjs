import http from 'node:http';
import {createHmac, randomBytes, timingSafeEqual} from 'node:crypto';
import {readFile, mkdir} from 'node:fs/promises';
import {resolve, extname, sep} from 'node:path';
import {pathToFileURL} from 'node:url';
import {Store, ApiError, ensure, DEMO_TARIFF, id} from './domain.mjs';
import {RazorpayTest, TwoFactorSms} from './providers.mjs';
import {receiptPdf} from './receipt.mjs';
import {PostgresDatabase} from './postgres.mjs';
import {PostgresStore} from './postgres-store.mjs';
import {createPreviewDashboard} from '../../enquiry-dashboard/scripts/dashboard-preview.mjs';
const root = resolve(import.meta.dirname, '../..');
const staticRoot = resolve(root, 'enquiry-dashboard/dist');
const mime = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css',
  '.js': 'text/javascript',
  '.png': 'image/png',
  '.webp': 'image/webp',
  '.jpg': 'image/jpeg',
  '.txt': 'text/plain'
};
const headers = {
  'Cache-Control': 'no-store',
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'no-referrer',
  'X-Frame-Options': 'DENY',
  'Content-Security-Policy': "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data: blob:; connect-src 'self' https://wpaickmgqlahzmdqmkid.supabase.co; object-src 'none'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'"
};
async function body(req, max = 9 * 1024 * 1024) {
  let size = 0, chunks = [];
  for await (const part of req) {
    size += part.length;
    ensure(size <= max, 'Request is too large.', 413);
    chunks.push(part);
  }
  return Buffer.concat(chunks);
}
function json(res, status, data) {
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8'
  }).end(JSON.stringify(data));
}
export function verifyEvent(raw, signature, secret) {
  ensure(typeof signature === 'string' && (/^[a-f0-9]{64}$/).test(signature), 'Invalid payment signature.', 401);
  const actual = createHmac('sha256', secret).update(raw).digest();
  ensure(timingSafeEqual(actual, Buffer.from(signature, 'hex')), 'Invalid payment signature.', 401);
  return JSON.parse(raw.toString());
}
export function canReceiveChange(user, event) {
  return user.role === 'admin' || event.users?.includes(user.id) === true || ['settings', 'fleet'].includes(event.kind);
}
export async function createApplication({dbPath = ':memory:', seed = true, photo, webhookSecret = randomBytes(32).toString('hex'), previewFile, payments = null, sms = null, databaseUrl=null} = {}) {
  ensure(process.env.NODE_ENV !== 'production', 'The local pilot server cannot run in production. Configure production identity, database, accounting and payment adapters first.', 503);
  const real=!!databaseUrl;
  const store = real?new PostgresStore(new PostgresDatabase(databaseUrl)):new Store(dbPath, {
    allowSampleTracking: true
  });
  if (seed&&!real) await store.seed(photo);
  if(real){await store.tariff();void store.db.listen();}
  const streams=new Map();
  const send=(res,event)=>{if(!res.destroyed)res.write(`data: ${JSON.stringify(event)}\n\n`);};
  if(real){
    store.db.on('change',event=>{for(const [res,client]of streams){if(canReceiveChange(client.user,event))send(res,{kind:event.kind,booking_id:event.booking_id});}});
    store.db.on('ready',()=>{for(const res of streams.keys())send(res,{kind:'reconnected'});});
    store.db.on('unavailable',()=>{for(const res of streams.keys())send(res,{kind:'connection_lost'});});
  }
  const enquiries = previewFile && !real ? await createPreviewDashboard({
    file: previewFile,
    localRecords: () => []
  }) : null;
  const attempts = new Map(), creating = new Map(), smsDaily = new Map();
  async function preparePayment(user, bookingId, base) {
    ensure(!real||payments,'Payments are not configured. Please contact PVG.',503);
    const local = await store.paymentOrder(user, bookingId);
    if (!payments) return local;
    if (!creating.has(local.id)) creating.set(local.id, (async () => {
      let order = await store.orderForCustomer(user, local.id), data = JSON.parse(order.data);
      if (!data.provider_order_id) {
        ensure(!data.creation_started, 'A previous order request is being checked. Do not make another payment; contact the pilot operator.', 409);
        await store.updateOrder(order.id, {
          creation_started: true,
          mode: 'razorpay_test'
        });
        let external;
        try {
          external = await payments.createOrder(order);
        } catch (error) {
          if (error.requestRejected) await store.updateOrder(order.id, {
            creation_started: false
          });
          throw error;
        }
        order = await store.updateOrder(order.id, {
          provider_order_id: external.id,
          creation_started: false,
          mode: 'razorpay_test'
        });
      }
      return order;
    })().finally(() => creating.delete(local.id)));
    const order = await creating.get(local.id);
    const token = await store.checkoutToken(order.id);
    return {
      ...local,
      mode: 'razorpay_test',
      checkout_url: `${base}/checkout#${token}`
    };
  }
  async function reconcile(order) {
    if (order.status === 'paid') return {
      paid: true
    };
    if (!payments) return {
      paid: false
    };
    const event = await payments.reconcile(order);
    if (event) await store.paymentEvent(event);
    return {
      paid: !!event
    };
  }
  const server = http.createServer(async (req, res) => {
    Object.entries(headers).forEach(([key, value]) => res.setHeader(key, value));
    try {
      const port = server.address()?.port;
      ensure([`127.0.0.1:${port}`, `localhost:${port}`, `[::1]:${port}`].includes(req.headers.host), 'Invalid host.', 403);
      const origins = new Set([`http://127.0.0.1:${port}`, `http://localhost:${port}`, 'http://127.0.0.1:8202', 'http://localhost:8202']);
      if (req.headers.origin) {
        ensure(origins.has(req.headers.origin), 'This origin is not allowed.', 403);
        res.setHeader('Access-Control-Allow-Origin', req.headers.origin);
        res.setHeader('Vary', 'Origin');
        res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
        res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
      }
      if (req.method === 'OPTIONS') {
        res.writeHead(204).end();
        return;
      }
      const url = new URL(req.url, `http://127.0.0.1:${port}`), path = url.pathname;
      if (path === '/__preview/dashboard' && enquiries) {
        await enquiries(req, res, url);
        return;
      }
      if (['/checkout', '/checkout.js'].includes(path) && req.method === 'GET') {
        res.setHeader('Content-Security-Policy', "default-src 'self'; script-src 'self' https://checkout.razorpay.com; style-src 'self' 'unsafe-inline'; img-src 'self' data: https://*.razorpay.com; connect-src 'self' https://*.razorpay.com; frame-src https://*.razorpay.com; object-src 'none'; base-uri 'none'; frame-ancestors 'none'");
        const file = await readFile(resolve(root, 'pvg-service/public', path === '/checkout' ? 'checkout.html' : 'checkout.js'));
        res.writeHead(200, {
          'Content-Type': path === '/checkout' ? mime['.html'] : mime['.js']
        }).end(file);
        return;
      }
      if (!path.startsWith('/api/')) {
        ensure(['GET', 'HEAD'].includes(req.method), 'Method not allowed.', 405);
        const target = resolve(staticRoot, '.' + decodeURIComponent(path === '/' ? '/operations.html' : path));
        ensure(target.startsWith(staticRoot + sep), 'Not found.', 404);
        try {
          const file = await readFile(target);
          res.writeHead(200, {
            'Content-Type': mime[extname(target)] || 'application/octet-stream'
          }).end(req.method === 'HEAD' ? undefined : file);
        } catch {
          throw new ApiError(404, 'Page not found.');
        }
        return;
      }
      if (path === '/api/config' && req.method === 'GET') {
        if(real){json(res,200,{mode:'supabase',database:'supabase_postgres',realtime:true,tariff:await store.tariff(),service_area:'Chennai',integrations:{otp:sms?'twofactor':'not_configured',sms_available:!!sms,payments:payments?'razorpay_test':'not_configured',zoho:'not_connected',setrans:'manual'}});return;}
        json(res, 200, {
          mode: 'local_preview',
          tariff: DEMO_TARIFF,
          service_area: 'Chennai preview area',
          integrations: {
            otp: sms ? 'twofactor_test' : 'local_test',
            sms_available: !!sms,
            payments: payments ? 'razorpay_test' : 'local_test',
            zoho: 'not_connected',
            setrans: 'manual'
          },
          demo_accounts: store.previewAccounts
        });
        return;
      }
      if (path === '/api/health' && req.method === 'GET') {
        json(res, 200, {
          ok: true,
          mode: real?'supabase':'local_preview'
        });
        return;
      }
      let input = {}, raw;
      if (req.method === 'POST') {
        ensure(req.headers['content-type']?.startsWith('application/json'), 'Use JSON for this request.', 415);
        raw = await body(req, (/\/reading$/).test(path) ? 17 * 1024 * 1024 : 65536);
        try {
          input = JSON.parse(raw.toString() || '{}');
        } catch {
          throw new ApiError(400, 'Invalid JSON request.');
        }
        ensure(input && typeof input === 'object' && !Array.isArray(input), 'Invalid request.');
      }
      if (path.startsWith('/api/auth/') && req.method === 'POST') {
        const key = req.socket.remoteAddress;
        let limit = attempts.get(key);
        if (!limit || limit.until < Date.now()) {
          limit = {
            n: 0,
            until: Date.now() + 60000
          };
          attempts.set(key, limit);
        }
        ensure(++limit.n <= 30, 'Too many sign-in requests. Please wait a minute.', 429);
        if (path === '/api/auth/login') {
          json(res, 200, await store.login(input.username, input.password));
          return;
        }
        if (path === '/api/auth/otp') {
          if(real){ensure(input.delivery==='sms','Sign in using the SMS verification code.',403);ensure(sms,'Mobile verification is not configured yet.',503);}
          ensure(['sms', 'preview', undefined].includes(input.delivery), 'Unsupported delivery method.');
          if (input.delivery === 'sms') {
            ensure(sms, 'SMS is not configured.', 503);
            ensure((/^[6-9]\d{9}$/).test(input.phone) && !(/^900000000[12]$/).test(input.phone), 'Use your own mobile number for test SMS.');
            const day = new Date().toISOString().slice(0, 10), smsKey = day + input.phone;
            ensure((smsDaily.get(smsKey) || 0) < 5, 'Daily test SMS limit reached.', 429);
            smsDaily.set(smsKey, (smsDaily.get(smsKey) || 0) + 1);
          }
          const challenge = await store.requestOtp(input.phone, input.name);
          if (input.delivery === 'sms') {
            try {
              await sms.send(input.phone, challenge.preview_code);
            } catch (error) {
              await store.db.prepare('DELETE FROM otps WHERE id=?').run(challenge.challenge_id);
              throw error;
            }
            delete challenge.preview_code;
            challenge.mode = 'sms';
            challenge.message = 'Test SMS accepted by 2Factor using the temporary Clickacook sender.';
          }
          json(res, 200, challenge);
          return;
        }
        if (path === '/api/auth/verify') {
          json(res, 200, await store.verifyOtp(input.challenge_id, input.code));
          return;
        }
      }
      if (path === '/api/webhooks/payments' && req.method === 'POST') {
        const event = verifyEvent(raw, req.headers['x-pvg-signature'], webhookSecret);
        json(res, 200, await store.paymentEvent(event));
        return;
      }
      if (path.startsWith('/api/checkout/') && req.method === 'POST') {
        ensure(payments, 'Test provider is not configured.', 503);
        const order = await store.checkoutOrder(input.token), data = JSON.parse(order.data);
        if (path === '/api/checkout/session') {
          json(res, 200, {
            key: payments.key,
            amount: order.amount,
            provider_order_id: data.provider_order_id
          });
          return;
        }
        if (path === '/api/checkout/verify') {
          ensure(input.razorpay_order_id === data.provider_order_id, 'The payment order does not match.', 409);
          payments.signature(data.provider_order_id, input.razorpay_payment_id, input.razorpay_signature);
          const event = await payments.verifiedPayment(order, input.razorpay_payment_id);
          await store.paymentEvent(event);
          json(res, 200, {
            paid: true
          });
          return;
        }
        if (path === '/api/checkout/refresh') {
          json(res, 200, await reconcile(order));
          return;
        }
        throw new ApiError(404, 'Endpoint not found.');
      }
      const token = req.headers.authorization?.replace(/^Bearer /, '');
      const user = await store.authenticate(token);
      if(path==='/api/events'&&req.method==='GET'){
        ensure(real,'Live events are not enabled in sample mode.',404);
        ensure(streams.size<150,'Too many live connections. Try again shortly.',503);
        res.writeHead(200,{'Content-Type':'text/event-stream','Cache-Control':'no-cache, no-transform','Connection':'keep-alive','X-Accel-Buffering':'no'});res.flushHeaders();
        streams.set(res,{token,user});send(res,{kind:'connected'});
        let checking=false;
        const heartbeat=setInterval(async()=>{if(checking)return;checking=true;try{await store.authenticate(token);res.write(': heartbeat\n\n');}catch{send(res,{kind:'session_expired'});res.end();}finally{checking=false;}},20000);
        res.on('close',()=>{clearInterval(heartbeat);streams.delete(res);});return;
      }
      if (path === '/api/me' && req.method === 'GET') {
        json(res, 200, {
          id: user.id,
          name: user.name,
          role: user.role,
          phone: user.phone
        });
        return;
      }
      if (path === '/api/auth/logout' && req.method === 'POST') {
        await store.logout(token);
        for(const [stream,client]of streams)if(client.token===token){send(stream,{kind:'session_expired'});stream.end();}
        json(res, 200, {
          ok: true
        });
        return;
      }
      if (path === '/api/evs' && req.method === 'GET') {
        json(res, 200, {
          vehicles: await store.evs(user)
        });
        return;
      }
      if (path === '/api/evs' && req.method === 'POST') {
        json(res, 201, await store.addEv(user, input));
        return;
      }
      if (path === '/api/profile' && req.method === 'POST') {
        json(res, 200, await store.updateProfile(user, input));
        return;
      }
      if (path === '/api/preferences' && req.method === 'GET') {
        json(res, 200, await store.preferences(user));
        return;
      }
      if (path === '/api/preferences' && req.method === 'POST') {
        json(res, 200, await store.setPreferences(user, input));
        return;
      }
      if (path === '/api/updates/read' && req.method === 'POST') {
        json(res, 200, await store.readUpdates(user));
        return;
      }
      if (path === '/api/places' && req.method === 'GET') {
        json(res, 200, {
          places: await store.places(user)
        });
        return;
      }
      if (path === '/api/places' && req.method === 'POST') {
        json(res, 201, await store.savePlace(user, input));
        return;
      }
      const personal = (/^\/api\/(evs|places)\/([a-zA-Z0-9_-]+)(?:\/(archive|delete))?$/).exec(path);
      if (personal && req.method === 'POST') {
        const [, kind, itemId, action] = personal;
        let result;
        if (kind === 'evs' && !action) result = await store.editEv(user, itemId, input); else if (kind === 'evs' && action === 'archive') result = await store.archiveEv(user, itemId); else if (kind === 'places' && !action) result = await store.savePlace(user, input, itemId); else if (kind === 'places' && action === 'delete') result = await store.deletePlace(user, itemId); else throw new ApiError(404, 'Endpoint not found.');
        json(res, 200, result);
        return;
      }
      if (path === '/api/fleet' && req.method === 'GET') {
        json(res, 200, await store.fleet(user));
        return;
      }
      if(path==='/api/fleet'&&req.method==='POST'){ensure(real,'Add actual vehicles in Supabase mode.',403);json(res,201,await store.addFleet(user,input));return;}
      if(path==='/api/technicians'&&req.method==='POST'){ensure(real,'Add actual staff in Supabase mode.',403);json(res,201,await store.addTechnician(user,input));return;}
      if (path === '/api/bookings' && req.method === 'GET') {
        json(res, 200, {
          bookings: await store.list(user)
        });
        return;
      }
      if (path === '/api/bookings' && req.method === 'POST') {
        json(res, 201, await store.createBooking(user, input));
        return;
      }
      const gps = (/^\/api\/bookings\/([a-zA-Z0-9_-]+)\/tracking(?:\/(start|stop))?$/).exec(path);
      if (gps) {
        const [, bookingId, action] = gps;
        if (!action && req.method === 'GET') {
          json(res, 200, await store.tracking(user, bookingId));
          return;
        }
        ensure(req.method === 'POST', 'Method not allowed.', 405);
        const method = ({
          start: 'startTracking',
          stop: 'stopTracking'
        })[action] || 'updateTracking';
        json(res, 200, await store[method](user, bookingId, input));
        return;
      }
      const match = (/^\/api\/bookings\/([a-zA-Z0-9_-]+)(?:\/(assign|status|reading|accept|dispute|cancel|payment-order|payment-refresh|receipt))?$/).exec(path);
      if (match) {
        const [, bookingId, action] = match;
        if (!action && req.method === 'GET') {
          json(res, 200, await store.detail(user, bookingId));
          return;
        }
        if (action === 'receipt' && req.method === 'GET') {
          const booking = await store.detail(user, bookingId, false);
          ensure(booking.invoice?.payment_status === 'paid', 'A receipt is available after a verified payment.', 409);
          res.writeHead(200, {
            'Content-Type': 'application/pdf',
            'Content-Disposition': `attachment; filename="${booking.reference}-test-receipt.pdf"`
          }).end(receiptPdf(booking));
          return;
        }
        ensure(req.method === 'POST', 'Method not allowed.', 405);
        if (action === 'payment-order') {
          json(res, 200, await preparePayment(user, bookingId, url.origin));
          return;
        }
        if (action === 'payment-refresh') {
          await store.role(user, 'customer');
          const booking = await store.detail(user, bookingId, false);
          const order = booking.invoice ? await store.db.prepare('SELECT * FROM payment_orders WHERE invoice_id=? ORDER BY rowid DESC LIMIT 1').get(booking.invoice.id) : null;
          json(res, 200, order ? await reconcile(order) : {
            paid: false
          });
          return;
        }
        const method = ({
          assign: 'assign',
          status: 'progress',
          reading: 'submitReading',
          accept: 'accept',
          dispute: 'dispute',
          cancel: 'cancel',
          'payment-order': 'paymentOrder'
        })[action];
        ensure(method, 'Not found.', 404);
        json(res, 200, await store[method](user, bookingId, input));
        return;
      }
      const simulation = (/^\/api\/test-payments\/([a-zA-Z0-9_-]+)$/).exec(path);
      if (simulation && req.method === 'POST') {
        ensure(!real,'Simulated payments are disabled for real bookings.',403);
        const order = await store.orderForCustomer(user, simulation[1]);
        ensure(!payments && JSON.parse(order.data).mode === 'local_test', 'Simulated payments are disabled when Razorpay is connected.', 403);
        ensure(['success', 'failure'].includes(input.result), 'Select a test result.');
        const event = {
          id: input.result === 'success' ? `test_capture_${order.id}` : id('test_failure'),
          type: input.result === 'success' ? 'payment.captured' : 'payment.failed',
          order_id: order.id,
          amount_paise: order.amount,
          currency: 'INR'
        };
        const bytes = Buffer.from(JSON.stringify(event)), signature = createHmac('sha256', webhookSecret).update(bytes).digest('hex');
        const verified = verifyEvent(bytes, signature, webhookSecret);
        await store.paymentEvent(verified);
        json(res, 200, {
          mode: 'local_test',
          result: input.result,
          message: 'Simulation only. No money collected.'
        });
        return;
      }
      throw new ApiError(404, 'Endpoint not found.');
    } catch (error) {
      if (error instanceof ApiError) json(res, error.status, {
        error: error.message
      }); else {
        console.error('PVG request failed:', error.name);
        json(res, 500, {
          error: 'Something went wrong. Please retry or contact support.'
        });
      }
    }
  });
  return {
    server,
    store,
    stopStreams() { for (const res of streams.keys()) res.end(); },
    webhookSecret
  };
}
if (import.meta.url === pathToFileURL(process.argv[1] || '').href) {
  const dir = resolve(root, 'pvg-service/.local');
  await mkdir(dir, {
    recursive: true,
    mode: 0o700
  });
  const photoBytes = await readFile(resolve(root, 'pvg-service/fixtures/demo-meter.png')).catch(() => null);
  const env = JSON.parse(await readFile(resolve(dir, 'providers.json'), 'utf8').catch(() => '{}'));
  const simulation = process.env.PVG_PAYMENT_MODE === 'simulation';
  const cloud=process.env.PVG_DATA_MODE!=='sample'?JSON.parse(await readFile(resolve(dir,'supabase.json'),'utf8')):null;
  ensure(!cloud || !simulation, 'Simulation payments require explicit sample data mode.', 503);
  const payments = !simulation && env.RAZORPAY_KEY_ID ? new RazorpayTest(env) : null, sms = env.TWOFACTOR_API_KEY ? new TwoFactorSms(env) : null;
  const app = await createApplication({
    payments,
    sms,
    databaseUrl:cloud?.database_url,
    dbPath: resolve(dir, simulation ? 'pilot-simulation.sqlite' : 'pilot.sqlite'),
    photo: photoBytes ? `data:image/png;base64,${photoBytes.toString('base64')}` : undefined,
    previewFile: resolve(dir, 'enquiries.json')
  });
  const port = Number(process.env.PVG_LOCAL_PORT || 8201);
  app.server.listen(port, '127.0.0.1', () => console.log(`PVG service: http://127.0.0.1:${port}/ — ${cloud?'Supabase records and live events; payments remain in Razorpay Test':'local sample data'}.`));
  for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => {
    app.stopStreams();
    app.server.close(async () => {
      await app.store.close();
      process.exit(0);
    });
  });
}
