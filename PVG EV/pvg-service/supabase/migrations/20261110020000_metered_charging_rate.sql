-- New charging visits use the owner's revised rate. Existing booking tariff snapshots and invoices remain unchanged.
BEGIN;
UPDATE pvg_app.settings
SET data = jsonb_set(data::jsonb, '{unit_rate_paise}', '2000'::jsonb)::text
WHERE id = 'tariff';
COMMIT;
