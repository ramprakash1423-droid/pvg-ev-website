# PVG EV — customer app and operations workspace

Customer Flutter app, admin/technician website and private booking service. The production PVG marketing website remains separate from this folder.

## Current customer journey

Book a doorstep visit → open **Track my charging vehicle** → PVG assigns a technician and vehicle → receive their shared GPS and status updates → technician submits meter evidence → customer accepts the units and bill → verified payment.

An active visit becomes the main Home experience. Tracking shows the real destination pin (when supplied), the assigned technician, vehicle registration, support/contact actions and the latest service events. A charging-vehicle marker is shown only when valid GPS has arrived. Missing assignments and interrupted GPS have explicit waiting/last-known states. No invented bookings, routes, arrival estimates or fleet locations are inserted.

Booking uses three compact steps: choose an EV, select the place and preferred time, and review. Home has no pricing or energy selector. The agreed tariff is disclosed at review; the actual bill is calculated only after the technician submits meter evidence. Small controls and short transitions respect reduced-motion preferences.

Service hours are **6:00 AM–11:00 PM IST**. Customers can check their area, place a parking pin on a map, resume an unfinished booking, request a new time before departure, and send a visit-linked support request. Staff can respond, publish delays/failed-visit reasons and configure service hours/coverage. Missing real fleet or team data stays subject to confirmation. Customer sessions restore using a server-validated cookie on web and secure device storage on mobile.

## Projects

- `customer-app/`: Flutter iOS, Android and browser customer experience.
- `enquiry-dashboard/`: existing enquiry workspace plus admin and technician charging operations.
- `pvg-service/`: Node 24 API, private Supabase/PostgreSQL persistence, access controls, live events, pricing and Razorpay Test integration.

## Run locally

From this folder:

```sh
node enquiry-dashboard/scripts/build-dashboard.mjs
cd pvg-service
npm ci
npm start
```

In another terminal, from this folder:

```sh
cd customer-app
flutter pub get
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8202
```

Customer preview: http://127.0.0.1:8202/
Operations: http://127.0.0.1:8201/

The service requires privately supplied `pvg-service/.local/supabase.json` with its restricted database URL, and `.local/providers.json` for approved test payment/SMS configuration. These are intentionally excluded. Never place service credentials in Flutter or commit them. Database setup is documented in `pvg-service/README.md`; existing migrations have already been applied to the current project and must not be rerun blindly.

## Actual configuration and remaining work

- ₹300 visit fee + ₹20/kWh + 18% tax, per PVG's instruction.
- Default mode uses Supabase; sample mode is explicit and separate for automated/local development tests.
- Customer mobile login requires a genuine SMS code. Vehicle and technician records must be entered by PVG.
- GPS currently comes from the assigned technician's foreground website, with permission. Physical-phone use needs a secured HTTPS service. Screen wake lock is requested where supported; background tracking, road ETA and closed-app push delivery are not claimed.
- Payments are Razorpay **Test Mode**. No real money is collected. Zoho Books is not configured.
- Setrans still controls charging equipment. Status and delivered energy are technician-reported; there is no charger API integration.
- The API is a local pilot and deliberately refuses production mode. GitHub contains source code, not a publicly deployed customer/payment service.

## Verification

```sh
cd customer-app && flutter analyze && flutter test
# From this folder:
node --test pvg-service/test/*.test.mjs
node --test enquiry-dashboard/tests/*.test.cjs
```

34 Flutter tests cover the booking-to-tracking handoff, active Home, missing GPS, destination-only mapping, stale readings, small screens, pricing and customer acceptance. 54 service tests, 10 dashboard tests and 41 Supabase workflow checks also passed. Database workflow checks use a rolled-back transaction; fixture data is not retained in Supabase. See the service README for the optional private database verification command.


The current runtime has an owner-authorized provisional 180-minute travel/service planning window. It is adjustable and is not an arrival or full-charge guarantee. The controlled real simulator journey verified SMS sign-in, booking persistence, assignment updates and one genuine Mac location fix through Chrome. Location updates on the Mac were intermittent and stale labels were verified. Continuous physical-phone tracking, actual delivered-energy evidence, acceptance and checkout still require a completed real charging visit.
