# PVG-EV — New website

The redesigned website, saved separately from the existing website at the repository root. This folder matches the client preview published on 17 October 2026, including the updated logo, responsive pages, mobile image transitions, guided enquiry forms and matching green team profiles.

Team order: Clement Fernandez, Fonda Sandra, Johnson Anthony, Cecilia.

## Run locally

Use Node.js 24. There are no external build dependencies.

```sh
cd new-site
npm test
npm start
```

Open http://127.0.0.1:8100/. If another local PVG preview is already using port 8100, stop that server first. After edits, run `npm run build` and reload. `npm run serve` serves the existing build.

## Enquiry storage

Hosted forms submit to the existing Supabase table `public.pvg_ev_charging_requests` in project `wpaickmgqlahzmdqmkid`. `site-config.js` contains the public anonymous browser key; no secret or service-role key is included. Row-level security permits anonymous inserts only. Enquiry review requires administrative access.

All four enquiry types (`request`, `contact`, `fleet`, `pilot`) share the existing schema. Every submitted field is retained in `payload`; operational fields are also mapped to dedicated columns. Charging requests require captured GPS coordinates. Short references such as `PVG-1001` are allocated by the `submit_pvg_ev_enquiry` database function. A private browser-generated submission ID makes retries safe; only the short reference is shown or included in WhatsApp. Existing long references remain valid. The migration is stored in `supabase/migrations/20261017000000_simple_enquiry_references.sql` and has been applied to the linked project. Table read permissions remain unchanged.

Localhost keeps using the local preview server and ignored `.preview/` receipt log. Hosted preview forms send real enquiries. WhatsApp remains an optional visitor-initiated handoff.

Robots exclusions and Vercel no-index headers are retained for client review. The preview URL uses live enquiry storage; the production domain has not been switched.

## Verified on 17 October 2026

- All four form types were submitted through the anonymous Supabase API and read back with administrative access. All mapped fields and complete payloads matched. The charging request used synthetic GPS coordinates.
- Contact, fleet and pilot forms were also submitted through the deployed browser UI; their saved records matched every entered field, including optional fields and all pilot interests.
- Duplicate references were rejected and anonymous enquiry reads remained blocked.
- All seven synthetic test enquiries were labelled as QA and closed after verification.
- Short references `PVG-1001` through `PVG-1004` were verified across all four types, including concurrent retry requests returning the same number and only one saved row. A browser submission confirmed `PVG-1005`, including its WhatsApp reference. All five short-reference tests were closed after verification.
- All 24 automated form tests and checks across 30 pages passed.

## Files

- Root HTML, CSS and JavaScript: website pages and interactions.
- `insights/` and `guides/`: articles and printable planning guides.
- `public/`, `assets/`, `downloads/`: images, brand assets and downloadable files.
- `scripts/`: dependency-free build, local server and site checks.
- `form-submit.js`: shared submission client for server-issued short references.
- `supabase/migrations/`: scoped database changes for this version; excluded from public builds.
- `tests/`: form validation, location and original field contract checks.
- `vercel.json`: preview build and response headers.

Generated `dist/`, local receipts, environment files and Vercel account metadata are ignored by Git.

The public GitHub Pages link above serves this `new-site/` folder from `main`. The current Vercel preview is https://pvg-ev-website-6cgyontmk-prakashs-projects-cb68dcaa.vercel.app/.

## Deploy this version separately

Use this folder as the Vercel project root, with `npm run build` as the build command and `dist` as the output directory. A deployment from the repository root continues to use the existing site. Production configuration and switching the live domain are separate actions.

## Public client website

https://ramprakash1423-droid.github.io/pvg-ev-website/new-site/
