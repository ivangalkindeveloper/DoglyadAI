-- Only the isolated Compose database created for this run may execute this fixture.
-- This is synthetic ledger state, not a verified purchase or a payment test.
DO $$ BEGIN
  IF current_database() <> 'regression' THEN RAISE EXCEPTION 'Wrong database'; END IF;
  IF (SELECT count(*) FROM billing_owners) <> 1 THEN RAISE EXCEPTION 'Expected exactly one fresh test owner'; END IF;
END $$;
INSERT INTO billing_subscriptions
  (id, owner_id, source, apple_environment, external_id, plan_id, entitlement,
   paid_until, is_revoked, is_auto_renewing, amount_minor, interval_months,
   interval_days, currency, updated_at)
SELECT '00000000-0000-4000-8000-000000000001', id, 'robokassa', NULL,
       'regression-synthetic-subscription', 'pro_monthly', 'pro',
       now() + interval '30 days', false, false, 0, 1, 0, 'RUB', now()
FROM billing_owners
ON CONFLICT (id) DO UPDATE SET plan_id = EXCLUDED.plan_id,
  entitlement = EXCLUDED.entitlement, paid_until = EXCLUDED.paid_until,
  is_revoked = false, is_auto_renewing = false, updated_at = now();

-- Fill the Development Pro daily allowance with isolated synthetic usage.
INSERT INTO billing_usage (id, owner_id, day, status, created_at)
SELECT 'f0000000-0000-4000-8000-' || lpad(n::text, 12, '0'), id,
       (now() AT TIME ZONE 'UTC')::date::text, 'completed', now()
FROM billing_owners CROSS JOIN generate_series(1, :regression_daily_allowance) AS n
ON CONFLICT (id) DO UPDATE SET day = EXCLUDED.day, status = 'completed';
