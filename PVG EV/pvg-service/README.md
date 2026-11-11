# PVG booking, evidence and billing service

A runnable Node 24 pilot for the Flutter customer app and the existing PVG dashboard. It deliberately listens only on loopback and refuses `NODE_ENV=production`. Do not deploy it as-is.

## Current Supabase mode — 10 November 2026

`npm start` now uses real Supabase records; sample data requires the explicit `npm run start:sample` command. The local server is not publicly deployed. Current tariff: ₹300 visit + ₹20/kWh + 18% tax on both, configured from the owner’s instruction. Bookings do not require an energy quantity and contain no price estimate. The bill is calculated only from a technician’s submitted reading; a delivered 15 kWh session totals ₹708. No sample customers, vehicles, bookings or GPS positions are imported into Supabase. Add real vehicles and technicians under **Vehicles & team**.

The applied migration is `supabase/migrations/20261110010000_pvg_app.sql`. It creates the private `pvg_app` schema, 16 tables, RLS, grants and change triggers in the existing project. Do not rerun it blindly: the initial policies and triggers are not idempotent. The approved `pvg_app_runtime` login is restricted to PVG tables. It has no Clickacook table access or access to `auth.users`. Only the existing PVG admin login/logout functions are additionally callable. Existing Clickacook credentials and auth/provider configuration remain unchanged.

Private `.local/supabase.json` contains `database_url` (mode 0600). Never commit or log it. Connections use the Supabase session pooler with certificate validation; `certs/supabase-ca.crt` is a public CA obtained from the official Supabase Studio certificate link. Database notifications use PostgreSQL LISTEN/NOTIFY and an authenticated `/api/events` stream; notifications contain invalidation IDs only, and customers fetch only their own records. This is not a public Supabase REST schema.

Customer login in this mode requires real SMS verification. Demo login, simulated payments and sample GPS are rejected. Staff admin login validates the existing PVG dashboard credential without changing its password; technician credentials are salted and hashed. Razorpay remains **Test Mode**, and Zoho remains unconnected. Payment verification never bypasses customer acceptance.

Verification: 54 service tests, 10 dashboard tests, 34 Flutter tests, and 41 real Supabase workflow assertions passed. Database assertions run in a rolled-back transaction and retain no test bookings. The actual service-hours row is saved independently as 06:00–23:00 IST with empty coverage until PVG configures its areas. Run `node scripts/verify-supabase.mjs` with the private connection file to repeat the rollback verification. Sequence values can advance during verification.

## Current service experience — 10 November 2026

`CustomerExperience` uses the existing private tables for service settings, booking drafts, rescheduling, support and customer-visible service notes. The additional `20261110030000_service_hours.sql` and `20261110040000_require_service_window.sql` migrations have been applied. They insert the PVG service-hours setting when absent and leave the visit planning duration unconfigured until PVG confirms it. No technician or vehicle rows have been invented.

- Public `GET /api/availability` exposes hours and request slots derived from actual coverage, vehicles, staff and bookings, not names or private addresses. Missing configuration produces a confirmation-required response.
- Admin `GET/POST /api/service-settings` configures IST hours, visit window and service pincodes.
- Customer `GET/POST /api/booking-draft` stores only their own draft. Creating a booking and clearing its draft are atomic.
- Version-checked `POST /api/bookings/:id/reschedule` works before departure and releases the old assignment. `.../support` creates a customer request or an admin response. `.../service-update` lets authorized staff publish a delay or cancel a failed pre-charging visit with a reason. These controls do not add admin approval to customer billing.
- Real customer sessions last seven days. Web OTP verification returns an HttpOnly/SameSite cookie without exposing the bearer token to JavaScript; cookie mutations require an allowed origin. Native clients keep their bearer token in platform secure storage. `GET /api/auth/session` validates restoration and logout revokes the session. The HTTP cookie is local-pilot-only; an eventual HTTPS deployment must add Secure and a deliberate production origin configuration.
- Technician phone GPS stays permission-based. The website requests screen wake lock where supported; old positions become last-known when the browser pauses GPS. Background handset GPS and closed-app notifications are not implemented.


The historical notes below describe earlier sample-mode checks; they are not current real customer data.

Explicit sample mode generates fresh local staff credentials at each startup; no fixed sample password is published. Supabase mode does not expose or accept sample accounts.

## Local setup

Build the existing dashboard from the repo root, then run this service:

```sh
node enquiry-dashboard/scripts/build-dashboard.mjs
cd pvg-service
npm start
```

Private data lives in `.local/`, ignored by Git. API base: `http://127.0.0.1:8201/api`. Dashboard: `http://127.0.0.1:8201/`. Ports can be set with `PVG_LOCAL_PORT`; browser CORS also permits the Flutter preview on port 8202.

For initial setup only, local Clickacook test provider settings can be imported from the repository root:

```sh
node pvg-service/scripts/import-clickacook-test-providers.mjs /path/to/clickacook_backend/.env
```

This copies only the Razorpay **test** key pair and 2Factor API/sender/template fields into `.local/providers.json` with mode 0600. It reads but does not modify Clickacook, and never imports Supabase service-role keys. No application secrets belong in the customer app, website, Git, logs or screenshots.

The active local configuration now uses the test pair downloaded after the user's 9 November rotation. Do not rerun the legacy Clickacook import over it: that project's saved test pair is outdated. Replace provider credentials only through private server configuration, preserving the other provider values, then restart the local service.

To test payment behavior without contacting Razorpay, start with `PVG_PAYMENT_MODE=simulation npm run start:sample`. This is an **explicit separate demonstration mode**, uses a separate `pilot-simulation.sqlite`, and labels payments as simulations. There is no automatic success fallback when Razorpay fails.

## Workflow and permissions

`requested → assigned → on_the_way → arrived → charging → awaiting_acceptance → awaiting_payment → paid`

- Admin assigns an actual configured vehicle and technician in Supabase mode (sample slots exist only in explicit sample mode), confirms compatibility, and cannot approve a bill on behalf of the customer.
- Technician sees only assigned jobs, advances progress and uploads session kWh/photo or cumulative start/end readings with both photos. The price comes from the booking tariff snapshot.
- Customer sees only their own jobs. Acceptance requires the exact latest reading, booking version, total and explicit consent. The accepted record is immutable and invoice creation is idempotent.
- A dispute goes to staff; corrected evidence must be accepted again by the customer. Cancellation is permitted before the technician departs.
- Payment order amounts are server-derived. Checkout signatures, provider order ownership, currency, amount and captured status are checked server-side. Repeated events/orders are deduplicated. Payment failures do not mark a job paid.
- Receipt PDF is available only after verified payment; local documents say **NO MONEY COLLECTED / NOT A TAX INVOICE**.

No API in this pilot starts/stops/resets a Setrans charger. Statuses are technician reports, not live charger telemetry.

## External connections

Razorpay API calls use `https://api.razorpay.com/v1`. Only `rzp_test_` keys are accepted. Checkout is at `/checkout`; its 15-minute scoped token is passed in a URL fragment, removed from browser history immediately, and stored hashed in the database. Provider secrets remain server-only. Checkout verification fetches the payment and captures only an authorized payment matching the stored test order. Manual reconciliation fetches payments belonging to that order if the app/browser closed before verification. Unknown order-creation outcomes are blocked pending reconciliation rather than blindly creating another payable order.

The old copied pair returned **401 Authentication failed on 9 November 2026**. The user regenerated the test keys, and the downloaded pair was imported privately into PVG. Actual Razorpay Test Mode checkout then completed for PVG-2001: a cancelled netbanking payment remained failed and one card payment was confirmed captured for INR 525.00. The local invoice, customer app and admin dashboard all show paid; the downloaded PDF is a test receipt. No real money was collected. No Clickacook live settings, hosted configuration or webhooks were modified. A dedicated verified Razorpay webhook, scheduled reconciliation, refunds and production credential management remain deployment work.

2Factor sends the existing `Clickacook_OTP` template with `CLKACK` sender over HTTPS. SMS is opt-in for manual testing, blocks synthetic seed numbers, hides codes in SMS-mode responses, applies resend/attempt/daily limits and invalidates failed challenges. No real SMS has yet been sent. Acknowledgment means provider acceptance, not confirmed handset delivery. Production SMS throttling must persist across processes and PVG needs its own DLT/template registration.

Zoho is intentionally marked `not_connected`: PVG has no account yet. No official invoices, GST assumptions, financial transactions or Zoho API claims are made. The next accounting adapter should map contacts, queue one invoice per accepted immutable reading and sync verified payments with durable retries and unique external references.

## Tests

```sh
npm test
# Existing dashboard regression checks, from repository root:
node --test enquiry-dashboard/tests/*.test.cjs
```

24 service tests cover integer money math, invalid evidence, ownership/role boundaries, revision conflicts, disputes, accepted-reading locking, booking/assignment conflicts, OTP/session limits, forged signatures, payment deduplication, test-key restrictions, provider verification, no leaked SMS code, complete HTTP acceptance/payment/PDF and Razorpay checkout routes using mocked providers. The payment-refresh regression covers recovery after a closed checkout, unpaid versus captured results, ownership checks and prevention of a second order after capture. The existing dashboard's 10 regression tests passed previously.

SQLite transactions protect local state; this is not a production scaling architecture. The opaque sample sessions and default sample accounts must be replaced/provisioned before public deployment. The original website enquiries, shared Clickacook Supabase auth and production PVG dashboard have not been changed by running this service.

## Provider investigation — 9 November 2026

The original local Clickacook test pair was rejected. Render was inspected read-only and held live-mode credentials only; its live secret was not revealed or copied. The user subsequently regenerated the shared test keys and downloaded them. Only that downloaded test pair was imported into PVG's ignored private configuration. Clickacook's source, Render configuration, live keys and webhook settings were not changed. Any other integrations using the retired test key require their own update; this work did not update Clickacook test builds.

The successful checkout and authoritative provider status were compared with the local invoice and audit trail. Customer acceptance precedes payment verification; no admin approval is part of billing. Only one test payment was captured. Payment-refresh now reaches its handler, verifies provider capture and returns the paid result; a repeated payment request on a paid bill is rejected with an accurate message. The customer downloaded the PDF through the local web app, and its rendered contents were checked. Physical-device checkout and production deployment remain pending.

## Customer experience additions — 9 November 2026

The local SQLite service now stores customer-owned saved places and preferences. `GET/POST /api/places`, `POST /api/places/:id`, and `POST /api/places/:id/delete` manage addresses. `POST /api/evs/:id` edits a garage vehicle; `/archive` removes it from future selection while preserving existing visit snapshots. `GET/POST /api/preferences` stores a preferred owned EV and reduced motion. `POST /api/updates/read` records a server-generated timestamp. `POST /api/profile` changes only the signed-in customer's display name. Staff and other customers cannot mutate these records. The existing booking, acceptance and payment routes are unchanged.

All 27 service tests pass, including ownership, input validation, immutable booked vehicle details, preference persistence and Razorpay Test payment verification. These additions do not migrate mobile records into production Supabase or enable push notifications.


## Visit GPS tracking — 10 November 2026

Authenticated endpoints: `GET /api/bookings/:id/tracking`, `POST .../tracking/start` (`consent: true`), `POST .../tracking` (sharing session id, latitude, longitude, accuracy, captured_at), and `POST .../tracking/stop` (session id). Only the currently assigned technician can publish; reads use booking ownership/admin/assigned-technician checks. GPS writes do not increment billing or booking versions. A new sharing session invalidates old-device callbacks. Only one visit per technician can share at a time.

Only the latest fix is stored, without a route history. Coordinate range, numeric accuracy (0–500 m), freshness (60 seconds) and ordering are validated. Public status is stale after 90 seconds; an abandoned session expires after 15 minutes and is cleared on access. Stop, cancellation, completion, assignment changes and staff sign-out clear the current point. No coordinates enter the audit trail. OS/browser foreground restrictions still apply.

The local server explicitly enables a labelled sample source; `Store` defaults to rejecting it. Production mode remains blocked. Sample coordinates are test data, never proof of a vehicle's position. The GPS verification suite covers permission boundaries, consent, stale/invalid/out-of-order fixes, lease replacement, ending sessions, HTTP routing and browser capture-controller behavior. All 39 service tests and 9 Flutter tests passed for this feature. No Clickacook provider configuration or live deployment changed.

Recovery checks cover denied GPS permission, a failed sharing start, retry controls after a panel refresh, booking-scoped error messages and successful upload after a temporary connection failure. A technician can retry after correcting permission or connection settings; no automatic permission prompt is triggered by dashboard refresh.


## Assignment consistency — 11 November 2026

Assignment now uses the same configured planning duration as availability and validates IST operating hours, including enough time before closing. An unset duration requires admin configuration; it does not silently become a two-hour booking. Public app configuration exposes only the service-hour/duration fields. The 54 service tests pass, including isolated regression checks for one-hour/three-hour windows and closing time; those tests create no live database rows.


Customer parking pins now have a conservative 150 km Chennai sanity check. This is an obvious-mismatch guard, not a service-coverage claim. Customers can update/remove an owned pin before departure with version checks; the audit contains no coordinates. Technician GPS is not moved or replaced by this rule.

At the owner's request, the current service window was set to a provisional 180 minutes including travel/service. This is a planning assumption, not measured PVG duration or a completion guarantee. Setrans lists multiple 10–30 kW mobile variants (https://www.setrans.co.in/mobile-charging-station.htm), and SparXcharge explains duration depends on EV/battery/charger (https://sparxcharge.com/calculator/); neither establishes a universal 180-minute service window. PVG should tune it using actual job timings. Operating hours remain 06:00–23:00 IST, and coverage pincodes remain unconfirmed.


The real browser GPS test exposed a host-timer receiver error (Illegal invocation). Default timers are now called through globalThis so they retain their browser receiver; a branded-host regression covers start, periodic fresh fixes and stop cleanup. No simulated GPS was substituted for the browser failure.


Controlled real GPS verification: the in-app browser supplied no fix after permission, while Chrome with one-time permission supplied a genuine device fix with 35 m accuracy. Supabase persisted the fix and the iPhone simulator displayed it. Later fixes were intermittent, so the app marked the point last-known/stale. Temporary Mac sharing was explicitly stopped and its stored point cleared. Continuous physical-phone tracking still needs a road test. No private coordinates are committed.

The owner confirmed no charging had occurred. No readings, invoices or payment orders were created to claim a completed live flow. Razorpay Test authentication was checked read-only; actual units acceptance and checkout remain unverified until genuine charging evidence is available.
