# PVG-EV — New website

The redesigned website, saved separately from the existing website at the repository root. This folder is the production website source for https://www.pvgev.com/, including the updated logo, responsive pages, mobile image transitions, guided enquiry forms and matching green team profiles.

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

## Private enquiry dashboard

The dashboard is a separate project in [../enquiry-dashboard/](../enquiry-dashboard/).
Live sign-in: https://pvg-ev-dashboard.vercel.app/. It uses the separate PVG-only
admin account; Google login is not used. See that project's README for local
preview, build, deployment and access details. Automatic WhatsApp alerts are not
activated.

The public pages are indexable for the production launch. Canonical URLs and the sitemap use https://www.pvgev.com/. The 404 page remains excluded from indexing. Both production and hosted previews use live enquiry storage.

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
- `vercel.json`: production build, canonical domain redirect and response headers.

Generated `dist/`, local receipts, environment files and Vercel account metadata are ignored by Git.

GitHub Pages also serves this `new-site/` folder from `main`. Share https://www.pvgev.com/ as the production client link.

## Production deployment

Vercel project `pvg-ev-website` uses `new-site` as its Root Directory, `npm run build` as the Build Command, and `dist` as the Output Directory. The connected `main` branch publishes this version. The original site files are retained at the repository root. The previous production deployment before the launch was `dpl_DZx9jmYc25VzTkFBohrMRzvZo3Gr` and can be promoted for rollback if needed.

## Public client website

https://www.pvgev.com/
