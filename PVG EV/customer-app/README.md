# PVG EV customer pilot

Flutter iOS, Android and browser app for doorstep EV charging. Admin and technicians use the existing operations website. Setrans equipment stays under Setrans control; no charger API integration is claimed.

## Run locally

Start the dashboard and service from the parent workspace:

```sh
node enquiry-dashboard/scripts/build-dashboard.mjs
cd pvg-service
npm ci
npm start
```

In another terminal:

```sh
cd customer-app
flutter pub get
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8202
```

Customer preview: http://127.0.0.1:8202/ · Staff: http://127.0.0.1:8201/

Default mode uses real Supabase records. Customer sign-in requires a genuine SMS code. Explicit sample mode is isolated and used for tests only; its people, bookings and GPS are not imported into Supabase. Private service credentials are excluded from Git.

## Customer experience

- Compact forest/lime UI, small controls, readable text and reduced-motion support. Home has no prices, quantity selector or advance charge calculator.
- Three booking steps: EV, place/time, review. The tariff is disclosed at review; the customer requests a visit and does not buy an advance quantity of energy.
- Saved EVs, preferred vehicle, saved places, optional customer GPS, manual parking pin on a map, access notes and server-saved unfinished booking drafts.
- Service hours: 6:00 AM–11:00 PM IST. Area checks use actual configured coverage and fleet/team records. Missing capacity stays subject to PVG confirmation, never invented availability.
- Active booking becomes the Home tracking screen. Actual technician/vehicle details appear after assignment, and a vehicle marker appears only after a valid phone GPS fix.
- Customer can request a new time before departure, cancel before departure, and send a visit-linked support request. Staff responses, delays and failed-visit explanations are visible in the app.
- Technician submits delivered units with meter evidence. The server calculates the actual bill; the customer accepts it and pays without admin billing approval.
- Razorpay Test checkout, verified payment status, history and a PDF test receipt. No real money or official Zoho tax invoice is produced.
- In-app service updates, FAQs and customer-initiated call/WhatsApp support.

The actual tariff is ₹300 visit + ₹20/kWh + 18% tax, supplied by PVG. Only delivered energy is billed. The home photograph illustrates the service; it is not live vehicle data.

## Sign-in and privacy

Real customer sessions last seven days, can be revoked on sign-out and are validated by the server on reopening. Browser sessions use HttpOnly cookies; native tokens use the platform secure store. Native keychain configuration is included. Staff sessions remain short-lived and in memory. No secret keys belong in the app.

## Technician phone GPS

The assigned technician opts into sharing through the staff website and grants phone location permission. The dashboard requests fresh fixes, asks supported browsers to keep the screen awake, and resumes updates when visible. A website cannot guarantee updates when the phone is locked or another app is used. The customer sees the captured time/accuracy and a last-known state when updates age or fail. No fabricated movement or road ETA is shown.

Stop, cancellation, completion, reassignment and staff sign-out clear the current point. Only the booking owner and authorized staff can access it. No route history is kept.

## Verification and remaining setup

`flutter analyze` and all 34 Flutter tests pass. Tests cover pricing-free Home, active tracking, missing/stale GPS, small screens with enlarged text, booking validation, customer acceptance, area checks and support submissions. The local browser layout and real Supabase availability response were checked.

Real technician names/numbers, vehicle registrations and coverage pincodes are still required. Physical-phone GPS and SMS delivery need handset testing over a secured hosted service. Localhost is accessible only on the development computer. The service intentionally refuses production mode and the app rejects HTTP in release mode.

Closed-app push notifications, address search/reverse geocoding, road ETA/routing, production payments, refunds and Zoho Books remain pending. The map supports manual pins and consent-based GPS now. In-app updates are not push delivery. No Clickacook provider settings or live payments were changed.


## Flow fixes — 11 November 2026

Successful OTP sign-in keeps its in-memory session if device storage is unavailable; fresh launches still validate saved sessions. Booking and rescheduling use configured hours in explicit IST and send UTC instants. Returning to an unpaid bill reconciles the provider status automatically, while the manual status check remains available.

All 34 Flutter tests and the iOS simulator build pass. The controlled real pilot verified customer SMS sign-in, booking persistence, actual staff/vehicle assignment and a genuine Mac location fix propagated through Supabase to the iPhone simulator. Location updates were intermittent; last-known/stale states and explicit sharing stop were verified. Physical-phone tracking and actual energy evidence, acceptance and checkout remain unverified until a completed charging visit.

An outside-Chennai simulator pin was detected and removed through the customer controls while preserving the written address. GPS/map validation now prevents obvious destination mismatches, and no replacement point is invented. Automated regression fixtures are separate from real pilot records and do not populate Supabase.
