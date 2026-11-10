-- PVG supplied 06:00–23:00 IST. Coverage must be entered by PVG; no fake areas/team.
INSERT INTO pvg_app.settings(id,data)
VALUES('service','{"open_minutes":360,"close_minutes":1380,"visit_minutes":120,"pincodes":[]}')
ON CONFLICT(id) DO NOTHING;
