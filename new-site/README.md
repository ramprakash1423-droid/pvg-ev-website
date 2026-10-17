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

## Preview behaviour

`site-config.js` sets `window.PVG_CONFIG = { demo: true }`, matching the current client preview. Hosted forms validate inputs and display a demo confirmation without sending enquiries to Supabase or WhatsApp. The local preview server can save test receipts in the ignored `.preview/` folder. No production database migration is included or applied.

Robots exclusions and Vercel no-index headers are retained for client review. This source snapshot is not a production launch.

## Files

- Root HTML, CSS and JavaScript: website pages and interactions.
- `insights/` and `guides/`: articles and printable planning guides.
- `public/`, `assets/`, `downloads/`: images, brand assets and downloadable files.
- `scripts/`: dependency-free build, local server and site checks.
- `tests/`: form validation, location and original field contract checks.
- `vercel.json`: preview build and response headers.

Generated `dist/`, local receipts, environment files and Vercel account metadata are ignored by Git.

## Deploy this version separately

Use this folder as the Vercel project root, with `npm run build` as the build command and `dist` as the output directory. A deployment from the repository root continues to use the existing site. Production configuration and switching the live domain are separate actions.

## Current client preview

https://pvg-ev-website-xcgr9j2ap-prakashs-projects-cb68dcaa.vercel.app/
