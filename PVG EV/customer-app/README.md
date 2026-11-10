# PVG EV customer pilot

Flutter customer app for doorstep/mobile EV charging. Admin and technicians use the existing `enquiry-dashboard/operations.html` website. The charger itself is operated in Setrans; no Setrans API integration is claimed.

## Run locally

From the repository root:

```sh
node enquiry-dashboard/scripts/build-dashboard.mjs
cd pvg-service
npm start
```

In another terminal:

```sh
cd customer-app
flutter pub get
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8202
# Or: flutter run -d <iPhone-simulator-id>
```

Customer browser preview: http://127.0.0.1:8202/
Staff dashboard: http://127.0.0.1:8201/

The default service uses real Supabase data. Sign in with a mobile number and its SMS code. No demo accounts or bookings appear in this mode. The existing PVG admin credential works in the operations website. Add actual technicians and charging vehicles under **Vehicles & team** before assigning visits.

Sample mode is available only through `npm run start:sample` in `pvg-service`; it uses the preserved local SQLite database. Do not confuse its records with Supabase.

The iPhone simulator reaches the host service using localhost. For Android emulator testing, use `adb reverse tcp:8201 tcp:8201`. Physical devices need a deliberately configured private HTTPS test service; do not expose this local pilot publicly. `PVG_API_URL` can be passed with `--dart-define`. Release mode rejects HTTP endpoints.

## Included in the customer experience

- Guest browsing and mobile SMS sign-in. No-SMS preview access exists only in explicit sample mode.
- Saved EV and connector details, charging address, opt-in GPS with manual address fallback, requested time, with no advance energy quantity or price estimate.
- Customer bookings, technician progress, session or cumulative meter evidence, itemised charges, disputes, explicit customer acceptance and locked billing.
- Test payment integration, verified-payment status and downloadable PDF test receipt.
- White/forest/lime home with a photographic hero, four-step service guide, address and EV pickers, compact quick actions, and reduced-motion preference. Home contains no prices, calculators or energy-quantity selections. Booking requests a visit; final charges appear only after the technician submits delivered units and evidence. A central Book action stays available in the five-item bottom navigation.
- Three-step booking: EV/energy, place/time, and itemized review. Explicit consent and a future time are required; the customer never pays while submitting the request.
- Per-customer saved places with access notes, optional GPS, edit/remove and shortcuts. Manually editing an address clears stale coordinates.
- EV editing, removal from the garage, preferred vehicle, and rebooking from history. Existing visit vehicle/address snapshots are preserved.
- Searchable visits, active/history/action filters, technician-reported progress, foreground refresh, meter photo zoom, and an activity centre with read state.
- Editable profile name, charging guide, visit checklist, FAQs, and customer-initiated call/WhatsApp support.
- Android/iOS/web projects. iPhone simulator and browser preview verified.

The current configured tariff is **₹20/kWh + ₹300 visit fee + 18% tax**, supplied by the owner. There is no advance estimate. Actual delivered units are billed automatically by the server; for example, a submitted 15 kWh reading totals ₹708 including the visit fee and tax. The home image illustrates the service; it is not a live vehicle feed. Actual vehicle registrations and technicians must be entered by PVG.

Supabase changes reach the signed-in app through an authenticated event stream. Reconnection refreshes the latest data; polling remains a fallback. Tracking shows actual assigned-technician GPS only after consent and a valid phone reading. No fabricated location or ETA is displayed. The 320 px layout with enlarged text, booking selections, acceptance controls and stale-location handling are covered by ten passing Flutter tests.

The following dated notes describe previous sample-mode work, preserved separately from current Supabase data.

## Provider status — 9 November 2026

- **Razorpay:** connected with the test pair regenerated and downloaded by the user on 9 November 2026. PVG-2001 completed a provider-confirmed card capture for INR 525.00 in Test Mode. Customer and admin views show paid, and the customer PDF receipt downloaded successfully. A cancelled netbanking attempt stayed unpaid. No real money was collected; live keys are rejected by this pilot. The secret stays in the local service, not in the app or source.
- **2Factor:** credentials imported into the service's ignored local configuration; temporary Clickacook sender/template supported. Adapter checks passed using a mock provider. No real SMS was sent; device delivery is not verified. PVG needs its own registered sender/template before launch.
- **Zoho Books:** not connected. User confirmed PVG does not yet have an account. Receipts are clearly marked test-only and are not tax invoices.
- **Supabase:** existing website enquiry integration is unchanged. New mobile bookings are stored only in local SQLite for this pilot, not in live Supabase.

## Checks

```sh
flutter analyze
flutter test
```

Nine Flutter tests cover map freshness/sample labels, pre-assignment tracking states, home-to-booking selections, guest browsing without OTP transmission, a 320px layout with 130% text, the complete booking wizard, clearing stale GPS after address edits, exact customer acceptance and session expiry. Backend tests cover permission boundaries, evidence, price integrity, stale reading rejection, idempotency, payments and receipt creation. See `../pvg-service/README.md`.

## Before a real pilot

Provision PVG production identity and individual staff accounts; replace local SQLite/demo access with a secured hosted database and private evidence storage; configure approved tariff/tax rules, current payment keys, verified webhooks and reconciliation; create/link the PVG Zoho organization; register PVG OTP templates and test delivery; add push notifications, session persistence, service-area and availability rules, operational support/refunds, observability and backups; test actual Setrans vehicles and physical Android/iPhones. App-store signing/release and live deployment are not included in this local build.

## Provider investigation — 9 November 2026

The original local Clickacook test pair was rejected. Render was inspected read-only and held live-mode credentials only; its live secret was not revealed or copied. The user subsequently regenerated the shared test keys and downloaded them. Only that downloaded test pair was imported into PVG's ignored private configuration. Clickacook's source, Render configuration, live keys and webhook settings were not changed. Any other integrations using the retired test key require their own update; this work did not update Clickacook test builds.

Provider verification confirmed one failed netbanking attempt followed by one captured card payment for the same INR 525.00 test order. Checkout reported verified, customer payment refresh and the staff dashboard showed paid, and the PDF download was inspected. The payment-refresh route was corrected and regression-tested; repeating payment after capture cannot create another order. Browser authentication was delayed during the test, so payment state is always confirmed with Razorpay rather than inferred from an open/closed checkout window. This verification covers the local web customer build; physical-device checkout and production deployment remain pending.

## Experience verification — 9 November 2026

The follow-up UI revision uses ChargeZone's official Google Play screenshots (https://play.google.com/store/apps/details?id=com.chargezone) as a reference for compact controls and persistent navigation, adapted to PVG doorstep booking. It does not copy station discovery or claim charger connectivity. Home address, EV and energy selections carry into the booking wizard; visit cards and page headings are more compact. The revised layout was checked in the browser and iPhone simulator.

A sample address was saved through the web UI, then appeared in the iPhone simulator for the same sample customer. The new booking wizard created PVG-2004 (15 kWh, INR 580 sample estimate); the existing staff dashboard displayed the same address, access notes and requested slot. The preferred EV control saved successfully. The earlier provider-verified PVG-2001 payment remains intact. No new real payment or SMS was sent during the redesign. All new customer preferences and bookings remain local; no GitHub push or production deployment was made.


## Assigned-visit GPS — 10 November 2026

The customer opens **My visits → Track vehicle** after assignment. The map receives the assigned technician's latest GPS fix, refreshes every 10 seconds while the booking is open, shows captured time/accuracy, and labels data older than 90 seconds or failed refreshes as last-known. It shows the customer's address pin only when coordinates were supplied; straight-line distance is explicitly not a road ETA. No customer GPS is requested by this screen.

The update-age label uses the server's snapshot time plus monotonic elapsed time, so a customer phone with an incorrect clock does not make an old position look live. The age continues updating between network refreshes. A failed refresh provides a retry action. GPS permission and start errors remain visible to the technician with working retry controls; the mobile sharing banner stays compact.

The technician uses **Share my live location** in the existing operations website, after explicit consent and browser location permission. The page requests fresh fixes about every 15 seconds; it does not relabel old coordinates as new. Keep that dashboard visible and the phone unlocked. Hiding the page stops device sharing; this is foreground website tracking, not reliable background fleet telemetry. Normal browser deployment requires HTTPS. Sharing also ends on completion, cancellation, assignment changes, sign-out or an explicit stop. Only the booking owner and authorized staff can read the feed.

Map tiles use OpenStreetMap with visible attribution, app identification and the map library's normal caching. `PVG_MAP_TILES` can select a licensed provider for deployment (matching provider attribution must also be updated). No routing or ETA service is configured. The local-only **Preview sample GPS** option shows a fixed, labelled sample pin without requesting device location; sample sharing may remain when switching preview tabs. Device GPS permission/delivery and road testing still need a physical technician phone with a secured hosted service.

Verification: PVG-2004 was assigned through the local admin UI to PVG Mobile 01 / Arun with a future sample slot (11 November, 10:00 IST). The technician UI started sample sharing; SQLite held one labelled sample point without changing booking version 2. The web app and iPhone simulator displayed the same map. Explicit Stop removed the customer pin, and restarting the sample restored it. No real device location, SMS or payment was used. The sample remains available locally and expires when inactive.
