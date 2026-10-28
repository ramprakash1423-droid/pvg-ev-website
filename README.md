# PVG-EV Website

Production-ready static website for PVG-EV by Prime Ventures Global, aligned to the July 2026 client revision brief.

## Main pages

- Home
- Mobile Charging Station
- Solutions
- Request Charging
- Fleet Solutions
- About PVG-EV
- PVG-EV × Setrans
- Pilot Programme
- Insights
- Contact

## Notes

The site positions PVG-EV as the local market-development, deployment and operating partner, and Setrans as the Mobile Charging Station technology partner.

## Local development

Run the static site through a local server:

```bash
npm run serve
```

Then open:

```text
http://localhost:8100/
```

Use the local server for validation instead of opening `index.html` directly with `file://`, so shared scripts, routes and browser behavior match the deployed site more closely.

## Separate projects

- [New public website](new-site/) — [client link](https://ramprakash1423-droid.github.io/pvg-ev-website/new-site/).
- [Private enquiry dashboard](enquiry-dashboard/) — [dashboard sign-in](https://pvg-ev-dashboard.vercel.app/). Includes its own build, preview server, tests and database setup source.
