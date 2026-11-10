// Supabase/PostgreSQL implementation of the PVG workflow. No sample seeding.
import {createHash, randomBytes, randomUUID, scryptSync, timingSafeEqual} from 'node:crypto';
import {ApiError,ensure,sha,now,id,energyMilli,billFor,photoData} from './domain.mjs';
const TRACKABLE=new Set(['assigned','on_the_way','arrived','charging']);
function passwordHash(password, salt = randomBytes(16).toString('hex')) {
  return `${salt}:${scryptSync(password, salt, 32).toString('hex')}`;
}
function passwordMatches(password, stored) {
  const [salt, hash] = stored.split(':');
  return timingSafeEqual(scryptSync(password, salt, 32), Buffer.from(hash, 'hex'));
}
const safeUser = user => ({
  id: user.id,
  name: user.name,
  role: user.role,
  phone: user.phone,
  username: user.username
});
export class PostgresStore {
  constructor(db) {
    this.db = db;
    this.allowSampleTracking = false;
    this.dummyPassword = passwordHash(randomBytes(32).toString('hex'));
  }
  async tx(fn) {
    return await this.db.tx(fn);
  }
  async user(userId) {
    return await this.db.prepare('SELECT * FROM users WHERE id=?').get(userId);
  }
  async tariff(){const row=await this.db.prepare("SELECT data FROM settings WHERE id='tariff'").get();return row?JSON.parse(row.data):null;}
  async loginExistingAdmin(username,password){
    const row=await this.db.prepare('SELECT public.pvg_dashboard_login(?,?) AS result').get(username,password);
    const result=row.result;
    ensure(result?.ok,result?.error==='rate_limited'?'Too many attempts. Try again in 15 minutes.':'Incorrect username or password.',result?.error==='rate_limited'?429:401);
    await this.db.prepare('SELECT public.pvg_dashboard_logout(?)').get(result.session_token);
    await this.db.prepare("INSERT INTO users(id,username,name,role) VALUES('pvg-admin','admin','PVG Admin','admin') ON CONFLICT(id) DO NOTHING").run();
    return this.newSession(await this.user('pvg-admin'));
  }
  async addTechnician(user,input){
    this.role(user,'admin');
    ensure(typeof input.name==='string'&&input.name.trim().length>=2&&input.name.length<=80,'Enter the technician’s name.');
    ensure(/^[6-9]\d{9}$/.test(input.phone),'Enter a valid 10-digit mobile number.');
    ensure(typeof input.username==='string'&&/^[a-z][a-z0-9._-]{2,39}$/.test(input.username)&&input.username!=='admin','Choose a user ID with 3–40 lowercase letters, numbers or dots.');
    ensure(typeof input.password==='string'&&input.password.length>=12&&input.password.length<=128,'Use a technician password with at least 12 characters.');
    const existing=await this.db.prepare('SELECT id FROM users WHERE username=? OR phone=?').get(input.username,input.phone);ensure(!existing,'That user ID or mobile number is already registered.',409);
    const techId=id('tech');await this.db.prepare("INSERT INTO users(id,username,phone,name,role,password) VALUES(?,?,?,?,'technician',?)").run(techId,input.username,input.phone,input.name.trim(),passwordHash(input.password));
    return {id:techId,name:input.name.trim(),username:input.username};
  }
  async addFleet(user,input){
    this.role(user,'admin');
    ensure(typeof input.name==='string'&&input.name.trim().length>=2&&input.name.length<=80,'Enter the charging vehicle name.');
    ensure(typeof input.registration==='string'&&/^[A-Z0-9 -]{5,20}$/.test(input.registration.trim().toUpperCase()),'Enter the actual vehicle registration.');
    ensure(typeof input.compatibility==='string'&&input.compatibility.trim().length>=2&&input.compatibility.length<=300,'Enter the supported connectors and charging specification.');
    const vehicle={id:id('fleet'),name:input.name.trim(),registration:input.registration.trim().toUpperCase(),compatibility:input.compatibility.trim(),available:true};
    await this.db.prepare('INSERT INTO fleet VALUES(?,?)').run(vehicle.id,JSON.stringify(vehicle));return vehicle;
  }
  async login(username, password) {
    ensure(typeof username === 'string' && typeof password === 'string' && username.length <= 64 && password.length <= 128, 'Enter your username and password.');
    if(username.trim().toLowerCase()==='admin') return this.loginExistingAdmin(username.trim().toLowerCase(),password);
    const user = await this.db.prepare("SELECT * FROM users WHERE username=? AND role!='customer'").get(username.trim().toLowerCase());
    ensure(!user || user.locked_until <= Date.now(), 'Too many attempts. Try again in 15 minutes.', 429);
    const valid = passwordMatches(password, user?.password || this.dummyPassword);
    if (!user || !valid) {
      if (user) await this.db.prepare('UPDATE users SET failures=failures+1, locked_until=? WHERE id=?').run(user.failures >= 4 ? Date.now() + 900000 : 0, user.id);
      throw new ApiError(401, 'Incorrect username or password.');
    }
    await this.db.prepare('UPDATE users SET failures=0,locked_until=0 WHERE id=?').run(user.id);
    return await this.newSession(user);
  }
  async requestOtp(phone, name = 'PVG customer') {
    ensure((/^[6-9]\d{9}$/).test(phone), 'Enter a 10-digit mobile number.');
    ensure(typeof name === 'string' && name.trim().length >= 2 && name.length <= 80, 'Enter your name.');
    const recent = await this.db.prepare('SELECT expires FROM otps WHERE phone=? ORDER BY expires DESC LIMIT 1').get(phone);
    ensure(!recent || recent.expires < Date.now() + 240000, 'Please wait a minute before requesting another code.', 429);
    await this.db.prepare('DELETE FROM otps WHERE phone=? OR expires<?').run(phone, Date.now());
    const challenge = id('otp'), code = String(100000 + randomBytes(4).readUInt32BE() % 900000);
    await this.db.prepare('INSERT INTO otps(id,phone,name,hash,expires) VALUES(?,?,?,?,?)').run(challenge, phone, name.trim(), sha(challenge + code), Date.now() + 300000);
    return {
      challenge_id: challenge,
      preview_code: code,
      expires_in: 300,
      mode: 'local_preview',
      message: 'Local test only. No SMS was sent.'
    };
  }
  async verifyOtp(challenge, code) {
    ensure(typeof challenge === 'string' && typeof code === 'string', 'Enter the verification code.');
    const otp = await this.db.prepare('UPDATE otps SET attempts=attempts+1 WHERE id=? AND expires>? AND attempts<5 RETURNING *').get(challenge,Date.now());
    ensure(otp, 'The code has expired. Request a new one.', 401);
    ensure(timingSafeEqual(Buffer.from(otp.hash, 'hex'), Buffer.from(sha(challenge + code), 'hex')), 'Incorrect verification code.', 401);
    const consumed=await this.db.prepare('DELETE FROM otps WHERE id=? RETURNING id').get(challenge);
    ensure(consumed,'That code has already been used. Request a new one.',401);
    let user = await this.db.prepare("SELECT * FROM users WHERE phone=? AND role='customer'").get(otp.phone);
    if (!user) {
      const userId = id('customer');
      await this.db.prepare("INSERT INTO users(id,phone,name,role) VALUES(?,?,?,'customer') ON CONFLICT(phone) DO NOTHING").run(userId, otp.phone, otp.name);
      user = await this.db.prepare("SELECT * FROM users WHERE phone=? AND role='customer'").get(otp.phone);
      ensure(user,'This number belongs to a staff account. Please use the staff dashboard.',403);
    }
    return await this.newSession(user);
  }
  async newSession(user) {
    const token = randomBytes(32).toString('hex');
    await this.db.prepare('DELETE FROM sessions WHERE expires<?').run(Date.now());
    await this.db.prepare('INSERT INTO sessions VALUES(?,?,?)').run(sha(token), user.id, Date.now() + 3600000);
    return {
      token,
      user: safeUser(user),
      expires_in: 3600
    };
  }
  async authenticate(token) {
    ensure(typeof token === 'string' && (/^[a-f0-9]{64}$/).test(token), 'Please sign in.', 401);
    const record = await this.db.prepare('SELECT * FROM sessions WHERE hash=? AND expires>?').get(sha(token), Date.now());
    ensure(record, 'Your session has expired. Please sign in again.', 401);
    return await this.user(record.user_id);
  }
  async logout(token) {
    const session = await this.db.prepare('SELECT user_id FROM sessions WHERE hash=?').get(sha(token));
    if (session) await this.db.prepare('DELETE FROM booking_tracking WHERE technician_id=?').run(session.user_id);
    await this.db.prepare('DELETE FROM sessions WHERE hash=?').run(sha(token));
  }
  role(user, role) {
    ensure(user?.role === role, 'This action is not available to your account.', 403);
  }
  async addEv(user, input) {
    await this.role(user, 'customer');
    for (const field of ['model', 'registration', 'connector']) ensure(typeof input[field] === 'string' && input[field].trim().length >= 2 && input[field].length < 100, `Enter a valid ${field}.`);
    const ev = {
      id: id('ev'),
      model: input.model.trim(),
      registration: input.registration.trim().toUpperCase(),
      connector: input.connector.trim()
    };
    await this.db.prepare('INSERT INTO evs VALUES(?,?,?)').run(ev.id, user.id, JSON.stringify(ev));
    return ev;
  }
  async evs(user) {
    await this.role(user, 'customer');
    return (await this.db.prepare('SELECT data FROM evs WHERE customer_id=?').all(user.id)).map(r => JSON.parse(r.data)).filter(ev => !ev.archived);
  }
  async ownedEv(user, evId) {
    await this.role(user, 'customer');
    const row = await this.db.prepare('SELECT data FROM evs WHERE id=? AND customer_id=?').get(evId, user.id);
    ensure(row && !JSON.parse(row.data).archived, 'EV not found.', 404);
    return JSON.parse(row.data);
  }
  async editEv(user, evId, input) {
    const ev = await this.ownedEv(user, evId);
    for (const field of ['model', 'registration', 'connector']) ensure(typeof input[field] === 'string' && input[field].trim().length >= 2 && input[field].length < 100, `Enter a valid ${field}.`);
    const next = {
      ...ev,
      model: input.model.trim(),
      registration: input.registration.trim().toUpperCase(),
      connector: input.connector.trim()
    };
    await this.db.prepare('UPDATE evs SET data=? WHERE id=?').run(JSON.stringify(next), evId);
    return next;
  }
  async archiveEv(user, evId) {
    return await this.tx(async () => {
      const ev = await this.ownedEv(user, evId);
      await this.db.prepare('UPDATE evs SET data=? WHERE id=?').run(JSON.stringify({
        ...ev,
        archived: true
      }), evId);
      if ((await this.preferences(user)).default_vehicle_id === evId) await this.setPreferences(user, {
        default_vehicle_id: null
      });
      return {
        ok: true
      };
    });
  }
  async preferences(user) {
    await this.role(user, 'customer');
    const row = await this.db.prepare('SELECT data FROM customer_preferences WHERE user_id=?').get(user.id);
    return {
      default_vehicle_id: null,
      reduced_motion: false,
      updates_read_at: null,
      ...row ? JSON.parse(row.data) : {}
    };
  }
  async setPreferences(user, input) {
    const next = await this.preferences(user);
    if (Object.hasOwn(input, 'default_vehicle_id')) {
      if (input.default_vehicle_id !== null) await this.ownedEv(user, input.default_vehicle_id);
      next.default_vehicle_id = input.default_vehicle_id;
    }
    if (Object.hasOwn(input, 'reduced_motion')) {
      ensure(typeof input.reduced_motion === 'boolean', 'Choose a valid motion preference.');
      next.reduced_motion = input.reduced_motion;
    }
    await this.writePreferences(user, next);
    return next;
  }
  async writePreferences(user, next) {
    await this.db.prepare('INSERT INTO customer_preferences VALUES(?,?) ON CONFLICT(user_id) DO UPDATE SET data=excluded.data').run(user.id, JSON.stringify(next));
  }
  async readUpdates(user) {
    const next = {
      ...await this.preferences(user),
      updates_read_at: now()
    };
    await this.writePreferences(user, next);
    return next;
  }
  async updateProfile(user, input) {
    await this.role(user, 'customer');
    ensure(typeof input.name === 'string' && input.name.trim().length >= 2 && input.name.length <= 80, 'Enter a name between 2 and 80 characters.');
    await this.db.prepare('UPDATE users SET name=? WHERE id=?').run(input.name.trim(), user.id);
    return safeUser(await this.user(user.id));
  }
  async places(user) {
    await this.role(user, 'customer');
    return (await this.db.prepare('SELECT data FROM places WHERE customer_id=? ORDER BY rowid DESC').all(user.id)).map(r => JSON.parse(r.data));
  }
  async savePlace(user, input, placeId = null) {
    await this.role(user, 'customer');
    if (placeId) {
      ensure(await this.db.prepare('SELECT id FROM places WHERE id=? AND customer_id=?').get(placeId, user.id), 'Saved place not found.', 404);
    } else ensure((await this.places(user)).length < 10, 'You can save up to 10 places.');
    ensure(typeof input.label === 'string' && input.label.trim().length >= 2 && input.label.length <= 40, 'Give this place a short name.');
    ensure(typeof input.address === 'string' && input.address.trim().length >= 8 && input.address.length <= 400, 'Enter the complete charging address.');
    ensure((/^600\d{3}$/).test(input.pincode), 'Use a Chennai pincode (600xxx).');
    ensure(typeof (input.access_notes ?? '') === 'string' && (input.access_notes ?? '').length <= 1000, 'Access instructions are too long.');
    const hasCoords = input.latitude != null || input.longitude != null;
    ensure(!hasCoords || Number.isFinite(input.latitude) && Number.isFinite(input.longitude) && Math.abs(input.latitude) <= 90 && Math.abs(input.longitude) <= 180, 'Choose a valid location.');
    const place = {
      id: placeId || id('place'),
      label: input.label.trim(),
      address: input.address.trim(),
      pincode: input.pincode,
      access_notes: input.access_notes || '',
      latitude: input.latitude ?? null,
      longitude: input.longitude ?? null
    };
    if (placeId) await this.db.prepare('UPDATE places SET data=? WHERE id=?').run(JSON.stringify(place), placeId); else await this.db.prepare('INSERT INTO places VALUES(?,?,?)').run(place.id, user.id, JSON.stringify(place));
    return place;
  }
  async deletePlace(user, placeId) {
    await this.role(user, 'customer');
    const result = await this.db.prepare('DELETE FROM places WHERE id=? AND customer_id=?').run(placeId, user.id);
    ensure(result.changes, 'Saved place not found.', 404);
    return {
      ok: true
    };
  }
  async row(bookingId) {
    const row = await this.db.prepare('SELECT * FROM bookings WHERE id=?').get(bookingId);
    ensure(row, 'Booking not found.', 404);
    return row;
  }
  canRead(user, row) {
    ensure(user.role === 'admin' || user.role === 'technician' && row.technician_id === user.id || user.role === 'customer' && row.customer_id === user.id, 'Booking not found.', 404);
  }
  checkVersion(row, input) {
    ensure(Number.isInteger(input.version) && input.version === row.version, 'This booking changed. Refresh before continuing.', 409);
  }
  async audit(booking, user, action, data = {}) {
    await this.db.prepare('INSERT INTO audit(booking_id,actor_id,action,created_at,data) VALUES(?,?,?,?,?)').run(booking, user.id, action, now(), JSON.stringify(data));
  }
  async save(row, data) {
    const next = {
      ...JSON.parse(row.data),
      ...data,
      updated_at: now()
    };
    if (!TRACKABLE.has(next.status) || next.technician_id !== row.technician_id || next.fleet_id !== row.fleet_id) await this.db.prepare('DELETE FROM booking_tracking WHERE booking_id=?').run(row.id);
    await this.db.prepare('UPDATE bookings SET technician_id=?,fleet_id=?,status=?,version=version+1,data=? WHERE id=?').run(next.technician_id || null, next.fleet_id || null, next.status, JSON.stringify(next), row.id);
  }
  async tracking(user, bookingId) {
    const row = await this.row(bookingId);
    await this.canRead(user, row);
    const eligible = TRACKABLE.has(row.status), base = {
      eligible,
      state: eligible ? 'not_sharing' : row.status === 'requested' ? 'awaiting_assignment' : 'ended',
      position: null,
      server_time: now()
    };
    if (!eligible) return base;
    const tracker = await this.db.prepare('SELECT * FROM booking_tracking WHERE booking_id=? AND technician_id=?').get(bookingId, row.technician_id);
    if (!tracker) return base;
    const point = tracker.point ? JSON.parse(tracker.point) : null;
    const age = Date.now() - Date.parse(point?.captured_at || tracker.started_at);
    if (age > 900000) {
      await this.db.prepare('DELETE FROM booking_tracking WHERE booking_id=?').run(bookingId);
      return {
        ...base,
        state: 'expired'
      };
    }
    return {
      ...base,
      state: point ? age <= 90000 ? 'live' : 'stale' : 'waiting',
      position: point,
      started_at: tracker.started_at,
      source: tracker.source
    };
  }
  async startTracking(user, bookingId, input) {
    await this.role(user, 'technician');
    return await this.tx(async () => {
      const row = await this.row(bookingId);
      await this.canRead(user, row);
      ensure(TRACKABLE.has(row.status), 'GPS sharing is available only during an assigned, active visit.', 409);
      ensure(input.consent === true, 'Confirm sharing your phone location with this customer and PVG admin.');
      const source = input.source || 'device';
      ensure(['device', 'sample'].includes(source), 'Invalid location source.');
      ensure(source !== 'sample' || this.allowSampleTracking, 'Sample GPS is disabled.', 403);
      const session = id('gps');
      await this.db.prepare('DELETE FROM booking_tracking WHERE technician_id=? OR booking_id=?').run(user.id, bookingId);
      await this.db.prepare('INSERT INTO booking_tracking VALUES(?,?,?,?,NULL,?)').run(bookingId, user.id, session, now(), source);
      if (source === 'sample') await this.updateTracking(user, bookingId, {
        session_id: session,
        latitude: 13.0188,
        longitude: 80.255,
        accuracy: 20,
        captured_at: now()
      });
      await this.audit(bookingId, user, 'gps_started');
      return {
        session_id: session,
        tracking: await this.tracking(user, bookingId)
      };
    });
  }
  async updateTracking(user, bookingId, input) { return this.tx(()=>this.updateTrackingLocked(user,bookingId,input)); }
  async updateTrackingLocked(user, bookingId, input) {
    await this.role(user, 'technician');
    const row = await this.row(bookingId);
    await this.canRead(user, row);
    ensure(TRACKABLE.has(row.status), 'GPS sharing has ended for this visit.', 409);
    await this.tracking(user, bookingId);
    const tracker = await this.db.prepare('SELECT * FROM booking_tracking WHERE booking_id=? AND technician_id=?').get(bookingId, user.id);
    ensure(tracker && tracker.session_id === input.session_id, 'GPS sharing stopped or moved to another device. Start sharing again.', 409);
    ensure(Number.isFinite(input.latitude) && Math.abs(input.latitude) <= 90 && Number.isFinite(input.longitude) && Math.abs(input.longitude) <= 180, 'GPS coordinates are invalid.');
    ensure(Number.isFinite(input.accuracy) && input.accuracy >= 0 && input.accuracy <= 500, 'GPS accuracy is too low. Move to an open area and try again.');
    const captured = Date.parse(input.captured_at);
    ensure(Number.isFinite(captured) && captured <= Date.now() + 5000 && captured >= Date.now() - 60000, 'GPS reading is out of date. Get a fresh location.');
    const previous = tracker.point ? JSON.parse(tracker.point) : null;
    ensure(!previous || captured >= Date.parse(previous.captured_at), 'An older GPS reading cannot replace a newer one.', 409);
    if (previous && captured === Date.parse(previous.captured_at)) return await this.tracking(user, bookingId);
    const point = {
      latitude: input.latitude,
      longitude: input.longitude,
      accuracy: input.accuracy,
      captured_at: new Date(captured).toISOString(),
      received_at: now()
    };
    await this.db.prepare('UPDATE booking_tracking SET point=? WHERE booking_id=? AND session_id=?').run(JSON.stringify(point), bookingId, input.session_id);
    return await this.tracking(user, bookingId);
  }
  async stopTracking(user, bookingId, input) {
    await this.role(user, 'technician');
    const row = await this.row(bookingId);
    await this.canRead(user, row);
    ensure(typeof input.session_id === 'string', 'A sharing session is required.');
    const result = await this.db.prepare('DELETE FROM booking_tracking WHERE booking_id=? AND technician_id=? AND session_id=?').run(bookingId, user.id, input.session_id);
    if (result.changes) await this.audit(bookingId, user, 'gps_stopped');
    return await this.tracking(user, bookingId);
  }
  async detail(user, bookingId, photos = true) {
    const row = await this.row(bookingId);
    await this.canRead(user, row);
    const data = JSON.parse(row.data);
    const readingRow = await this.db.prepare('SELECT * FROM readings WHERE booking_id=? ORDER BY revision DESC LIMIT 1').get(bookingId);
    let reading = readingRow ? {
      ...JSON.parse(readingRow.data),
      id: readingRow.id,
      revision: readingRow.revision
    } : null;
    if (reading && !photos) {
      const {photo, start_photo, ...small} = reading;
      reading = small;
    }
    const invoiceRow = await this.db.prepare('SELECT * FROM invoices WHERE booking_id=?').get(bookingId);
    const invoice = invoiceRow ? {
      ...JSON.parse(invoiceRow.data),
      id: invoiceRow.id
    } : null;
    const tech = row.technician_id ? await this.user(row.technician_id) : null;
    const customer = await this.user(row.customer_id);
    const events = (await this.db.prepare('SELECT action,created_at,data FROM audit WHERE booking_id=? ORDER BY id').all(bookingId)).map(r => ({
      action: r.action,
      created_at: r.created_at,
      ...JSON.parse(r.data)
    }));
    return {
      ...data,
      id: row.id,
      reference: `PVG-${row.seq}`,
      version: row.version,
      status: row.status,
      customer: {
        name: customer.name,
        phone: customer.phone
      },
      technician: tech ? {
        id: tech.id,
        name: tech.name,
        phone: TRACKABLE.has(row.status) ? tech.phone : null
      } : null,
      tracking: await this.tracking(user, bookingId),
      reading,
      invoice,
      events
    };
  }
  async list(user) {
    let rows;
    if (user.role === 'admin') rows = await this.db.prepare('SELECT id FROM bookings ORDER BY seq DESC LIMIT 200').all(); else if (user.role === 'technician') rows = await this.db.prepare('SELECT id FROM bookings WHERE technician_id=? ORDER BY seq DESC LIMIT 200').all(user.id); else rows = await this.db.prepare('SELECT id FROM bookings WHERE customer_id=? ORDER BY seq DESC LIMIT 200').all(user.id);
    return await Promise.all(rows.map(async row => await this.detail(user, row.id, false)));
  }
  async createBooking(user, input) { return this.tx(()=>this.createBookingLocked(user,input)); }
  async createBookingLocked(user, input) {
    await this.role(user, 'customer');
    ensure(typeof input.request_key === 'string' && input.request_key.length >= 8 && input.request_key.length <= 100, 'A booking request ID is required.');
    const fingerprint = sha(JSON.stringify({
      vehicle_id: input.vehicle_id,
      address: input.address,
      pincode: input.pincode,
      latitude: input.latitude ?? null,
      longitude: input.longitude ?? null,
      slot: input.slot,
      estimated_kwh: input.estimated_kwh,
      access_notes: input.access_notes || ''
    }));
    const previous = await this.db.prepare('SELECT * FROM bookings WHERE customer_id=? AND request_key=?').get(user.id, input.request_key);
    if (previous) {
      ensure(previous.request_hash === fingerprint, 'This request ID was used for a different booking.', 409);
      return await this.detail(user, previous.id);
    }
    const ev = await this.db.prepare('SELECT data FROM evs WHERE id=? AND customer_id=?').get(input.vehicle_id, user.id);
    ensure(ev && !JSON.parse(ev.data).archived, 'Select one of your saved EVs.');
    ensure(typeof input.address === 'string' && input.address.trim().length >= 8 && input.address.length <= 400, 'Enter the complete charging address.');
    ensure((/^600\d{3}$/).test(input.pincode), 'PVG currently accepts Chennai pincodes (600xxx).');
    const date = Date.parse(input.slot);
    ensure(Number.isFinite(date) && date > Date.now() && date < Date.now() + 31 * 86400000, 'Choose a future time within the next 30 days.');
    ensure(typeof (input.access_notes || '') === 'string' && (input.access_notes || '').length <= 1000, 'Access instructions are too long.');
    const hasCoords = input.latitude != null || input.longitude != null;
    ensure(!hasCoords || typeof input.latitude === 'number' && typeof input.longitude === 'number' && Math.abs(input.latitude) <= 90 && Math.abs(input.longitude) <= 180, 'Choose a valid location.');
    const tariff = await this.tariff();
    ensure(tariff, 'PVG pricing is not configured yet. Please contact support.',503);
    return await this.tx(async () => {
      const seq = (await this.db.prepare("SELECT nextval('pvg_app.booking_reference') AS n").get()).n, bookingId = id('booking');
      const data = {
        created_at: now(),
        updated_at: now(),
        status: 'requested',
        ev: JSON.parse(ev.data),
        address: input.address.trim(),
        pincode: input.pincode,
        latitude: input.latitude ?? null,
        longitude: input.longitude ?? null,
        slot: new Date(date).toISOString(),
        access_notes: input.access_notes || '',
        tariff: {
          ...tariff
        },
        estimate: null,
        billing_basis: 'metered_after_charging',
        is_demo: false
      };
      await this.db.prepare('INSERT INTO bookings VALUES(?,?,?,?,?,?,?,?,?,?)').run(bookingId, seq, user.id, null, null, 'requested', 1, input.request_key, fingerprint, JSON.stringify(data));
      await this.audit(bookingId, user, 'requested');
      return await this.detail(user, bookingId);
    });
  }
  async fleet(user) {
    await this.role(user, 'admin');
    return {
      vehicles: (await this.db.prepare('SELECT data FROM fleet').all()).map(r => JSON.parse(r.data)),
      technicians: await this.db.prepare("SELECT id,name,username FROM users WHERE role='technician'").all()
    };
  }
  async assign(user, bookingId, input) {
    await this.role(user, 'admin');
    return await this.tx(async () => {
      const row = await this.row(bookingId);
      await this.checkVersion(row, input);
      ensure(['requested', 'assigned'].includes(row.status), 'This booking can no longer be assigned.', 409);
      ensure(input.compatibility_confirmed === true, 'Confirm vehicle and connector compatibility before assignment.');
      ensure((await this.user(input.technician_id))?.role === 'technician', 'Select a technician.');
      const fleet = await this.db.prepare('SELECT data FROM fleet WHERE id=?').get(input.fleet_id);
      ensure(fleet && JSON.parse(fleet.data).available, 'Select an available vehicle.');
      const date = Date.parse(input.slot);
      ensure(Number.isFinite(date) && date > Date.now() && date < Date.now() + 31 * 86400000, 'Select a future arrival window within 30 days.');
      const active = await this.db.prepare("SELECT data FROM bookings WHERE id!=? AND status NOT IN ('cancelled','paid') AND (fleet_id=? OR technician_id=?)").all(bookingId, input.fleet_id, input.technician_id);
      ensure(!active.some(r => Math.abs(Date.parse(JSON.parse(r.data).slot) - date) < 120 * 60000), 'That vehicle or technician already has a booking in this two-hour service window.', 409);
      await this.save(row, {
        status: 'assigned',
        technician_id: input.technician_id,
        fleet_id: input.fleet_id,
        fleet_name: JSON.parse(fleet.data).name,
        fleet_registration: JSON.parse(fleet.data).registration,
        slot: new Date(date).toISOString(),
        compatibility_confirmed: true
      });
      await this.audit(bookingId, user, 'assigned', {
        note: JSON.parse(fleet.data).name
      });
      return await this.detail(user, bookingId);
    });
  }
  async progress(user, bookingId, input) {
    await this.role(user, 'technician');
    return await this.tx(async () => {
      const row = await this.row(bookingId);
      await this.canRead(user, row);
      await this.checkVersion(row, input);
      const next = ({
        assigned: 'on_the_way',
        on_the_way: 'arrived',
        arrived: 'charging'
      })[row.status];
      ensure(next && input.status === next, 'This job cannot move to that stage.', 409);
      await this.save(row, {
        status: next,
        ...next === 'charging' ? {
          charging_started_at: now()
        } : {}
      });
      await this.audit(bookingId, user, next);
      return await this.detail(user, bookingId);
    });
  }
  async submitReading(user, bookingId, input) {
    await this.role(user, 'technician');
    return await this.tx(async () => {
      const row = await this.row(bookingId);
      await this.canRead(user, row);
      await this.checkVersion(row, input);
      ensure(['charging', 'awaiting_acceptance', 'disputed'].includes(row.status), 'The customer has accepted this bill, or charging has not started. The reading cannot be changed.', 409);
      ensure(['session', 'cumulative'].includes(input.kind), 'Select session units or cumulative meter readings.');
      const photo = photoData(input.photo);
      let start_photo = null, start_milli = null, end_milli = null;
      let milli;
      if (input.kind === 'cumulative') {
        start_milli = energyMilli(input.start);
        end_milli = energyMilli(input.end);
        ensure(end_milli > start_milli, 'The ending meter must be greater than the starting meter.');
        start_photo = photoData(input.start_photo);
        milli = end_milli - start_milli;
      } else milli = energyMilli(input.units);
      ensure(typeof (input.notes || '') === 'string' && (input.notes || '').length <= 1000, 'Notes must be under 1,000 characters.');
      const revision = (await this.db.prepare('SELECT COALESCE(MAX(revision),0)+1 AS n FROM readings WHERE booking_id=?').get(bookingId)).n;
      const reading = {
        kind: input.kind,
        photo,
        start_photo,
        start_milli,
        end_milli,
        bill: billFor(milli, JSON.parse(row.data).tariff),
        notes: input.notes || '',
        submitted_at: now(),
        submitted_by: user.id
      };
      await this.db.prepare('INSERT INTO readings VALUES(?,?,?,?)').run(id('reading'), bookingId, revision, JSON.stringify(reading));
      await this.save(row, {
        status: 'awaiting_acceptance',
        charging_completed_at: now(),
        dispute: null
      });
      await this.audit(bookingId, user, 'reading_submitted', {
        revision
      });
      return await this.detail(user, bookingId);
    });
  }
  async accept(user, bookingId, input) {
    await this.role(user, 'customer');
    return await this.tx(async () => {
      const row = await this.row(bookingId);
      await this.canRead(user, row);
      const detail = await this.detail(user, bookingId, false);
      if (detail.invoice) {
        ensure(detail.invoice.reading_id === input.reading_id && detail.invoice.bill.total_paise === input.total_paise, 'The accepted bill differs from this request.', 409);
        return detail;
      }
      await this.checkVersion(row, input);
      ensure(row.status === 'awaiting_acceptance', 'There is no bill ready to accept.', 409);
      ensure(input.accepted === true, 'Please confirm that you accept the units and itemised total.');
      ensure(detail.reading?.id === input.reading_id && detail.reading.bill.total_paise === input.total_paise, 'The reading changed. Review the current photo and bill before accepting.', 409);
      const invoice = {
        booking_reference: detail.reference,
        reading_id: detail.reading.id,
        accepted_by: user.id,
        accepted_at: now(),
        bill: detail.reading.bill,
        number: `PVG-${row.seq}`,
        is_demo: false,
        zoho_status: 'not_connected',
        payment_status: 'unpaid'
      };
      await this.db.prepare('INSERT INTO invoices VALUES(?,?,?,?)').run(id('invoice'), bookingId, detail.reading.id, JSON.stringify(invoice));
      await this.save(row, {
        status: 'awaiting_payment'
      });
      await this.audit(bookingId, user, 'customer_accepted', {
        revision: detail.reading.revision,
        total_paise: detail.reading.bill.total_paise
      });
      return await this.detail(user, bookingId);
    });
  }
  async dispute(user, bookingId, input) {
    await this.role(user, 'customer');
    return await this.tx(async () => {
      const row = await this.row(bookingId);
      await this.canRead(user, row);
      await this.checkVersion(row, input);
      ensure(row.status === 'awaiting_acceptance', 'Only an unaccepted reading can be disputed here.', 409);
      ensure(typeof input.reason === 'string' && input.reason.trim().length >= 5 && input.reason.length <= 1000, 'Please explain the issue (5–1,000 characters).');
      await this.save(row, {
        status: 'disputed',
        dispute: input.reason.trim()
      });
      await this.audit(bookingId, user, 'customer_reported_issue', {
        note: input.reason.trim()
      });
      return await this.detail(user, bookingId);
    });
  }
  async cancel(user, bookingId, input) {
    ensure(['admin', 'customer'].includes(user.role), 'Only the customer or admin can cancel.', 403);
    return await this.tx(async () => {
      const row = await this.row(bookingId);
      await this.canRead(user, row);
      await this.checkVersion(row, input);
      ensure(['requested', 'assigned'].includes(row.status), 'Contact support to cancel a job already in progress.', 409);
      await this.save(row, {
        status: 'cancelled'
      });
      await this.audit(bookingId, user, 'cancelled');
      return await this.detail(user, bookingId);
    });
  }
  async paymentOrder(user, bookingId) {
    await this.role(user, 'customer');
    return await this.tx(async () => {
      const booking = await this.detail(user, bookingId, false);
      ensure(booking.status !== 'paid', 'This bill is already paid. Check payment status to view your receipt.', 409);
      ensure(booking.status === 'awaiting_payment' && booking.invoice, 'Accept the bill before paying.', 409);
      let order = await this.db.prepare("SELECT * FROM payment_orders WHERE invoice_id=? AND status='pending'").get(booking.invoice.id);
      if (!order) {
        const orderId = id('order'), data = {
          created_at: now(),
          booking_id: bookingId,
          customer_id: user.id,
          currency: 'INR',
          mode: 'razorpay_test'
        };
        await this.db.prepare('INSERT INTO payment_orders VALUES(?,?,?,?,?)').run(orderId, booking.invoice.id, 'pending', booking.invoice.bill.total_paise, JSON.stringify(data));
        order = await this.db.prepare('SELECT * FROM payment_orders WHERE id=?').get(orderId);
      }
      return {
        id: order.id,
        amount_paise: order.amount,
        currency: 'INR',
        mode: 'razorpay_test',
        message: 'Test checkout. No money will be collected.'
      };
    });
  }
  async paymentEvent(event) {
    return await this.tx(async () => {
      ensure(typeof event.id === 'string' && event.id.length < 120, 'Invalid payment event.');
      const old = await this.db.prepare('SELECT * FROM payment_events WHERE id=?').get(event.id);
      if (old) {
        ensure(old.data === JSON.stringify(event), 'Payment event conflict.', 409);
        return {
          duplicate: true
        };
      }
      ensure(['payment.captured', 'payment.failed'].includes(event.type), 'Unsupported payment event.');
      const order = await this.db.prepare('SELECT * FROM payment_orders WHERE id=?').get(event.order_id);
      ensure(order, 'Unknown payment order.', 404);
      ensure(Number.isSafeInteger(event.amount_paise) && event.amount_paise === order.amount && event.currency === 'INR', 'Payment amount or currency does not match.', 409);
      const invoiceRow = await this.db.prepare('SELECT * FROM invoices WHERE id=?').get(order.invoice_id);
      const invoice = JSON.parse(invoiceRow.data);
      if (event.type === 'payment.captured') {
        ensure(invoice.payment_status !== 'paid' || invoice.payment_order_id === order.id, 'This invoice was already paid using another order.', 409);
        if (invoice.payment_status !== 'paid') {
          await this.db.prepare("UPDATE payment_orders SET status='paid' WHERE id=?").run(order.id);
          await this.db.prepare('UPDATE invoices SET data=? WHERE id=?').run(JSON.stringify({
            ...invoice,
            payment_status: 'paid',
            paid_at: now(),
            payment_order_id: order.id,
            provider_reference: event.id
          }), invoiceRow.id);
          await this.save(await this.row(invoiceRow.booking_id), {
            status: 'paid'
          });
          await this.audit(invoiceRow.booking_id, {
            id: 'payment-provider'
          }, 'payment_verified', {
            mode: JSON.parse(order.data).mode
          });
        }
      } else if (order.status !== 'paid') {
        await this.db.prepare("UPDATE payment_orders SET status='failed' WHERE id=?").run(order.id);
      }
      await this.db.prepare('INSERT INTO payment_events VALUES(?,?,?)').run(event.id, order.id, JSON.stringify(event));
      return {
        ok: true
      };
    });
  }
  async orderForCustomer(user, orderId) {
    await this.role(user, 'customer');
    const row = await this.db.prepare('SELECT * FROM payment_orders WHERE id=?').get(orderId);
    ensure(row && JSON.parse(row.data).customer_id === user.id, 'Payment order not found.', 404);
    return row;
  }
  async updateOrder(orderId, fields) {
    const order = await this.db.prepare('SELECT * FROM payment_orders WHERE id=?').get(orderId);
    ensure(order, 'Payment order not found.', 404);
    await this.db.prepare('UPDATE payment_orders SET data=? WHERE id=?').run(JSON.stringify({
      ...JSON.parse(order.data),
      ...fields
    }), orderId);
    return await this.db.prepare('SELECT * FROM payment_orders WHERE id=?').get(orderId);
  }
  async checkoutToken(orderId) {
    const token = randomBytes(32).toString('hex');
    await this.db.prepare('DELETE FROM checkout_sessions WHERE expires<?').run(Date.now());
    await this.db.prepare('INSERT INTO checkout_sessions VALUES(?,?,?)').run(sha(token), orderId, Date.now() + 900000);
    return token;
  }
  async checkoutOrder(token) {
    ensure(typeof token === 'string' && (/^[a-f0-9]{64}$/).test(token), 'Reopen checkout from the app.', 401);
    const session = await this.db.prepare('SELECT * FROM checkout_sessions WHERE hash=? AND expires>?').get(sha(token), Date.now());
    ensure(session, 'Checkout expired. Reopen it from the app.', 401);
    return await this.db.prepare('SELECT * FROM payment_orders WHERE id=?').get(session.order_id);
  }
  async close() {
    await this.db.close();
  }
}
