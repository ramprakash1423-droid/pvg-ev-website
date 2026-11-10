-- PVG supplied working hours only. Require a confirmed planning window before suggesting slots.
-- Preserve any setting already edited by an administrator.
UPDATE pvg_app.settings
SET data = (data::jsonb || '{"visit_minutes":null}'::jsonb)::text
WHERE id='service' AND NOT (data::jsonb ? 'updated_at')
  AND (data::jsonb ->> 'visit_minutes')='120';
