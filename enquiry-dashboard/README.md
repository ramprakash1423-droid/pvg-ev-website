# PVG private enquiry dashboard

## Live dashboard

URL: **https://pvg-ev-dashboard.vercel.app/**

Vercel project `pvg-ev-dashboard` (`prj_9Jwr9g69u3lgFRYYbdBSz9ypbArf`), team
`prakashs-projects-cb68dcaa`. Production deployment on 28 October 2026:
`dpl_89Y2RPZ6oiy7aLxr9cUn5nvHBfAM`.

The dashboard now uses the separate **admin** username and the password explicitly
supplied by the owner. Google login has been removed. The password is not included
in any source file, static asset or deployment. It was provisioned through a
private temporary database script that was deleted immediately after execution.
Only a salted bcrypt cost-12 hash is stored in the private database schema.

Clickacook authentication settings, OAuth clients, SMTP, application code and
user passwords were not changed for this switch. No Supabase Auth account is
created, modified or impersonated. Previously saved PVG enquiries stay in the
same database table; public website forms are unchanged.

This folder is an independent project within the PVG website repository. It has
its own package scripts, static assets, preview server, tests and Vercel config.
The client website continues to live in `../new-site/`.

## Login and access controls

The migration `supabase/migrations/20261028010000_pvg_username_login.sql` adds only
PVG-specific objects to project `wpaickmgqlahzmdqmkid`:

- `pvg_private.dashboard_credentials`: one admin record, salted password hash,
  credential version and persistent failed-attempt counter. Five incorrect
  attempts lock login for 15 minutes. Row locking serializes concurrent attempts.
- `pvg_private.dashboard_sessions`: random 256-bit opaque tokens, stored as SHA-256
  hashes, with a one-hour expiry and credential-version binding. Raw tokens are
  returned only on successful login and held in browser memory.
- Private list/status functions restricted to `pvg_ev_website` enquiries.
- Public `pvg_dashboard_login` and `pvg_dashboard_logout` RPCs; session-protected
  `pvg_dashboard_session_list` and `pvg_dashboard_session_update_status` RPCs.

Credential/session tables have RLS and no public, anonymous or authenticated
access. Private functions/schema have no public access. Every data operation
validates the opaque session in the database. Session tokens are supplied in POST
bodies, never URLs. No service-role key is used or shipped to the browser.
Incorrect-login responses return normally so attempt counters commit rather
than rolling back. Expired, revoked and credential-version-mismatched sessions
cannot read or change enquiries. Sign-out revokes the presented PVG session and
immediately clears the UI; it does not sign out or alter any Clickacook account.

The former Google-account PVG RPCs (`pvg_dashboard_list`,
`pvg_dashboard_update_status`) have their anonymous/authenticated execute grants
revoked. Older dashboard deployments therefore cannot access enquiries through
the retired Google login. Shared Supabase provider settings are untouched.

Status updates are limited to the existing five values, check the last loaded
update time, preserve submitted fields, and append audit entries labelled
`PVG admin`. `changed_by` is null for this separate account rather than falsely
attributing changes to the owner's Clickacook identity. Original audit rows remain.

## Frontend and deployment

Features: category filters, search, status/date filters, summary counts, paging,
full submitted fields, GPS map links, follow-up statuses and 60-second refreshes
while visible. Dates use India time. Applicant values render as text, and links
are built from validated coordinates/phone digits. Contact links only send
messages when the user acts; status changes do not notify customers.

Passwords are cleared from the input immediately on submit. No passwords,
sessions or enquiries are persisted in browser storage. Sessions expire in
memory before server expiry. Browser back/forward cache restoration requires
sign-in again. Stale Google return parameters are removed, not followed.

`npm run build` packages 12 explicitly allowed static files in ignored `dist/`.
SQL, credentials, receipts and test data are excluded. For a Vercel Git project,
set Root Directory to `enquiry-dashboard`, Build Command to `npm run build`, and
Output Directory to `dist`. The existing live deployment is separate; pushing
this folder does not relink or change that project's configuration. The page is publicly accessible;
customer data is protected independently by the database. Headers prevent
caching, indexing and framing, with a restrictive Content Security Policy.

The two Supabase migrations are setup source, not deployment steps. The live
database already has the dashboard setup; do not rerun migrations merely to
publish the frontend. A fresh environment first needs the website enquiry table
and migrations from `../new-site/supabase/migrations/`, plus `pgcrypto` in the
`extensions` schema. Apply the dashboard foundation and username migration in
timestamp order, then provision the admin password privately. No production
password or hash is committed. The published foundation deliberately disables
the retired account-based access and omits the former owner's account identity.

`form-schema.js` and the two branding images are snapshots from `new-site` so this
project can build on its own. Sync the schema when website enquiry fields change.
`site-config.js` contains only the public anonymous browser key; it is not an
administrator credential and cannot read enquiries without a valid PVG session.

## Verification

- The separated projects pass 10 dashboard tests, 24 website tests and structural/link checks across 30 website pages. The standalone preview loads six sample enquiries, filters correctly and has no browser warnings or horizontal overflow.
- `supabase/verify-dashboard-username.sql` passed in a transaction that rolled
  back its synthetic credentials, sessions, test row and audit changes. It checks
  login, persisted lockout, private table/function access, fabricated sessions,
  real list/status operations, preservation of submitted fields, stale/invalid
  writes, audit attribution, sign-out, expiry and retirement of Google endpoints.
- The deployed page returns 200 and contains username/password fields with no
  Google button. Missing-session enquiry reads return 401; the retired public
  Google RPC also returns 401 for anonymous visitors.
- Successful browser login and logout are checked on the live deployment without
  editing any real enquiry. The inbox contains 2 new requests and 12 closed QA rows.

Use `supabase/verify-dashboard-username.sql` in a controlled database test session.
It rolls back all its changes; it is not run automatically by the frontend build.

## Local preview

Use Node.js 24. No external packages are required.

```sh
cd enquiry-dashboard
npm test
npm start
```

Open http://127.0.0.1:8101/?preview=1.
Local sample mode offers six synthetic enquiries and separate local form-test
receipts. It never reads live data. Preview status changes stay in ignored
`.preview/dashboard-status.json` and never rewrite the original form receipts.
Local API access requires same-origin headers/host and binds only to loopback.
Submitting the local login screen redirects to the canonical live dashboard;
it does not send the password to the local preview API.

For local form receipts, optionally set `PVG_PREVIEW_RECEIPTS` to the path of the
website's ignored `.preview/enquiries.jsonl` before starting the server. Without
it, the "Local form tests" view is empty. Reload receipts by restarting the server.
Set `PVG_DASHBOARD_PREVIEW_PORT` to use another loopback port. After editing frontend
files, run `npm run build` and reload the browser.

## WhatsApp

Automatic alerts are not connected. The selected recipient is +91 97510 83000;
an approved WhatsApp Business API sender/provider is still needed separately.
